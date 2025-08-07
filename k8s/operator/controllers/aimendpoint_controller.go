/*
Copyright 2024 AMD.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	aimv1alpha1 "github.com/aim-engine/operator/api/v1alpha1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	autoscalingv2 "k8s.io/api/autoscaling/v2"
)

// AIMEndpointReconciler reconciles a AIMEndpoint object
type AIMEndpointReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimendpoints,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimendpoints/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimendpoints/finalizers,verbs=update
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimrecipes,verbs=get;list;watch
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimcaches,verbs=get;list;watch
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch
//+kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=persistentvolumeclaims,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=autoscaling,resources=horizontalpodautoscalers,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=monitoring.coreos.com,resources=servicemonitors,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=monitoring.coreos.com,resources=prometheusrules,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
func (r *AIMEndpointReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the AIMEndpoint instance
	aimEndpoint := &aimv1alpha1.AIMEndpoint{}
	err := r.Get(ctx, req.NamespacedName, aimEndpoint)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			logger.Info("AIMEndpoint resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the request.
		logger.Error(err, "Failed to get AIMEndpoint")
		return ctrl.Result{}, err
	}

	// Check if the resource is being deleted
	if !aimEndpoint.DeletionTimestamp.IsZero() {
		return r.handleDeletion(ctx, aimEndpoint)
	}

	// Add finalizer if not present
	if !containsString(aimEndpoint.Finalizers, "aimendpoint.aim.engine.amd.com/finalizer") {
		aimEndpoint.Finalizers = append(aimEndpoint.Finalizers, "aimendpoint.aim.engine.amd.com/finalizer")
		if err := r.Update(ctx, aimEndpoint); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Update status to indicate reconciliation is in progress
	if aimEndpoint.Status.Phase != "Reconciling" {
		aimEndpoint.Status.Phase = "Reconciling"
		aimEndpoint.Status.Conditions = []metav1.Condition{
			{
				Type:               "Reconciling",
				Status:             metav1.ConditionTrue,
				Reason:             "Reconciling",
				Message:            "Reconciling AIMEndpoint",
				LastTransitionTime: metav1.Now(),
			},
		}
		if err := r.Status().Update(ctx, aimEndpoint); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Select recipe if auto-selection is enabled
	if err := r.selectRecipe(ctx, aimEndpoint); err != nil {
		logger.Error(err, "Failed to select recipe")
		aimEndpoint.Status.Phase = "Failed"
		aimEndpoint.Status.Conditions = []metav1.Condition{
			{
				Type:               "Failed",
				Status:             metav1.ConditionTrue,
				Reason:             "RecipeSelectionFailed",
				Message:            fmt.Sprintf("Failed to select recipe: %v", err),
				LastTransitionTime: metav1.Now(),
			},
		}
		r.Status().Update(ctx, aimEndpoint)
		return ctrl.Result{RequeueAfter: time.Minute}, err
	}

	// Create or update ConfigMap
	if err := r.reconcileConfigMap(ctx, aimEndpoint); err != nil {
		logger.Error(err, "Failed to reconcile ConfigMap")
		return ctrl.Result{}, err
	}

	// Create or update PVC if caching is enabled
	if aimEndpoint.Spec.Cache.Enabled != nil && *aimEndpoint.Spec.Cache.Enabled {
		if err := r.reconcilePVC(ctx, aimEndpoint); err != nil {
			logger.Error(err, "Failed to reconcile PVC")
			return ctrl.Result{}, err
		}
	}

	// Create or update Deployment
	if err := r.reconcileDeployment(ctx, aimEndpoint); err != nil {
		logger.Error(err, "Failed to reconcile Deployment")
		return ctrl.Result{}, err
	}

	// Create or update Service
	if err := r.reconcileService(ctx, aimEndpoint); err != nil {
		logger.Error(err, "Failed to reconcile Service")
		return ctrl.Result{}, err
	}

	// Create or update HPA if scaling is configured
	if aimEndpoint.Spec.Scaling.MaxReplicas != nil && *aimEndpoint.Spec.Scaling.MaxReplicas > 1 {
		if err := r.reconcileHPA(ctx, aimEndpoint); err != nil {
			logger.Error(err, "Failed to reconcile HPA")
			return ctrl.Result{}, err
		}
	}

	// Create or update monitoring resources if enabled
	if aimEndpoint.Spec.Monitoring.Enabled != nil && *aimEndpoint.Spec.Monitoring.Enabled {
		if err := r.reconcileMonitoring(ctx, aimEndpoint); err != nil {
			logger.Error(err, "Failed to reconcile monitoring resources")
			return ctrl.Result{}, err
		}
	}

	// Update status
	if err := r.updateStatus(ctx, aimEndpoint); err != nil {
		logger.Error(err, "Failed to update status")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled AIMEndpoint")
	return ctrl.Result{RequeueAfter: time.Minute * 5}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *AIMEndpointReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&aimv1alpha1.AIMEndpoint{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&corev1.PersistentVolumeClaim{}).
		Owns(&autoscalingv2.HorizontalPodAutoscaler{}).
		Complete(r)
}

// selectRecipe selects the appropriate recipe for the endpoint
func (r *AIMEndpointReconciler) selectRecipe(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	if endpoint.Spec.Recipe.AutoSelect {
		// Auto-select recipe based on model and available hardware
		recipe, err := r.findBestRecipe(ctx, endpoint.Spec.Model.ID)
		if err != nil {
			return err
		}
		
		// Find the best configuration for the requested GPU count
		var bestConfig *aimv1alpha1.GPUConfiguration
		requestedGPUCount := int32(1)
		if endpoint.Spec.Resources.GPUCount != nil {
			requestedGPUCount = *endpoint.Spec.Resources.GPUCount
		}
		
		for i := range recipe.Spec.Configurations {
			config := &recipe.Spec.Configurations[i]
			if config.Enabled && config.GPUCount == requestedGPUCount {
				bestConfig = config
				break
			}
		}
		
		if bestConfig == nil {
			return fmt.Errorf("no suitable configuration found for %d GPUs", requestedGPUCount)
		}
		
		endpoint.Status.SelectedRecipe = &aimv1alpha1.SelectedRecipeStatus{
			Name:      recipe.Name,
			GPUCount:  &bestConfig.GPUCount,
			Precision: recipe.Spec.Precision,
			Backend:   recipe.Spec.Backend,
		}
	} else if endpoint.Spec.Recipe.CustomRecipe != nil {
		// Use custom recipe
		recipe := &aimv1alpha1.AIMRecipe{}
		recipeName := endpoint.Spec.Recipe.CustomRecipe.Name
		recipeNamespace := endpoint.Namespace
		if endpoint.Spec.Recipe.CustomRecipe.Namespace != "" {
			recipeNamespace = endpoint.Spec.Recipe.CustomRecipe.Namespace
		}
		
		err := r.Get(ctx, types.NamespacedName{Name: recipeName, Namespace: recipeNamespace}, recipe)
		if err != nil {
			return fmt.Errorf("failed to get custom recipe %s: %v", recipeName, err)
		}
		
		endpoint.Status.SelectedRecipe = &aimv1alpha1.SelectedRecipeStatus{
			Name:      recipe.Name,
			Precision: recipe.Spec.Precision,
			Backend:   recipe.Spec.Backend,
		}
	}
	
	return nil
}

// findBestRecipe finds the best recipe for a given model
func (r *AIMEndpointReconciler) findBestRecipe(ctx context.Context, modelID string) (*aimv1alpha1.AIMRecipe, error) {
	recipes := &aimv1alpha1.AIMRecipeList{}
	err := r.List(ctx, recipes)
	if err != nil {
		return nil, err
	}
	
	var bestRecipe *aimv1alpha1.AIMRecipe
	for i := range recipes.Items {
		recipe := &recipes.Items[i]
		if recipe.Spec.ModelID == modelID {
			if bestRecipe == nil || recipe.CreationTimestamp.Before(&bestRecipe.CreationTimestamp) {
				bestRecipe = recipe
			}
		}
	}
	
	if bestRecipe == nil {
		return nil, fmt.Errorf("no recipe found for model %s", modelID)
	}
	
	return bestRecipe, nil
}

// reconcileConfigMap creates or updates the ConfigMap for the endpoint
func (r *AIMEndpointReconciler) reconcileConfigMap(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-config", endpoint.Name),
			Namespace: endpoint.Namespace,
		},
	}
	
	_, err := ctrl.CreateOrUpdate(ctx, r.Client, configMap, func() error {
		configMap.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-endpoint",
			"app.kubernetes.io/instance":  endpoint.Name,
			"app.kubernetes.io/component": "config",
		}
		
		configMap.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(endpoint, aimv1alpha1.GroupVersion.WithKind("AIMEndpoint")),
		}
		
		// Add configuration data
		configMap.Data = map[string]string{
			"model.id":       endpoint.Spec.Model.ID,
			"model.version":  endpoint.Spec.Model.Version,
			"model.revision": endpoint.Spec.Model.Revision,
		}
		
		if endpoint.Status.SelectedRecipe != nil {
			configMap.Data["recipe.name"] = endpoint.Status.SelectedRecipe.Name
			configMap.Data["recipe.precision"] = endpoint.Status.SelectedRecipe.Precision
			configMap.Data["recipe.backend"] = endpoint.Status.SelectedRecipe.Backend
		}
		
		return nil
	})
	
	return err
}

// reconcilePVC creates or updates the PersistentVolumeClaim for caching
func (r *AIMEndpointReconciler) reconcilePVC(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	pvc := &corev1.PersistentVolumeClaim{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-cache", endpoint.Name),
			Namespace: endpoint.Namespace,
		},
	}
	
	_, err := ctrl.CreateOrUpdate(ctx, r.Client, pvc, func() error {
		pvc.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-endpoint",
			"app.kubernetes.io/instance":  endpoint.Name,
			"app.kubernetes.io/component": "cache",
		}
		
		pvc.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(endpoint, aimv1alpha1.GroupVersion.WithKind("AIMEndpoint")),
		}
		
		pvc.Spec = corev1.PersistentVolumeClaimSpec{
			AccessModes: []corev1.PersistentVolumeAccessMode{corev1.ReadWriteOnce},
			Resources: corev1.ResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceStorage: resource.MustParse(endpoint.Spec.Cache.Size),
				},
			},
		}
		
		if endpoint.Spec.Cache.StorageClass != "" {
			pvc.Spec.StorageClassName = &endpoint.Spec.Cache.StorageClass
		}
		
		if endpoint.Spec.Cache.AccessMode != "" {
			pvc.Spec.AccessModes = []corev1.PersistentVolumeAccessMode{corev1.PersistentVolumeAccessMode(endpoint.Spec.Cache.AccessMode)}
		}
		
		return nil
	})
	
	return err
}

// reconcileDeployment creates or updates the Deployment
func (r *AIMEndpointReconciler) reconcileDeployment(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      endpoint.Name,
			Namespace: endpoint.Namespace,
		},
	}
	
	_, err := ctrl.CreateOrUpdate(ctx, r.Client, deployment, func() error {
		deployment.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-endpoint",
			"app.kubernetes.io/instance":  endpoint.Name,
			"app.kubernetes.io/component": "server",
		}
		
		deployment.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(endpoint, aimv1alpha1.GroupVersion.WithKind("AIMEndpoint")),
		}
		
		// Set replicas
		replicas := int32(1)
		if endpoint.Spec.Scaling.MinReplicas != nil {
			replicas = *endpoint.Spec.Scaling.MinReplicas
		}
		deployment.Spec.Replicas = &replicas
		
		// Set selector
		deployment.Spec.Selector = &metav1.LabelSelector{
			MatchLabels: map[string]string{
				"app.kubernetes.io/name":     "aim-endpoint",
				"app.kubernetes.io/instance": endpoint.Name,
			},
		}
		
		// Set template
		deployment.Spec.Template.ObjectMeta.Labels = deployment.Spec.Selector.MatchLabels
		
		// Set containers
		container := corev1.Container{
			Name:  "aim-server",
			Image: r.getImage(endpoint),
			Ports: []corev1.ContainerPort{
				{
					Name:          "http",
					ContainerPort: 8000,
					Protocol:      corev1.ProtocolTCP,
				},
			},
			Resources: r.getResourceRequirements(endpoint),
			Env:       r.getEnvironmentVariables(endpoint),
		}
		
		// Add volume mounts if caching is enabled
		if endpoint.Spec.Cache.Enabled != nil && *endpoint.Spec.Cache.Enabled {
			container.VolumeMounts = append(container.VolumeMounts, corev1.VolumeMount{
				Name:      "model-cache",
				MountPath: "/workspace/model-cache",
			})
		}
		
		deployment.Spec.Template.Spec.Containers = []corev1.Container{container}
		
		// Initialize volumes slice
		deployment.Spec.Template.Spec.Volumes = []corev1.Volume{}
		
		// Add volumes if caching is enabled
		if endpoint.Spec.Cache.Enabled != nil && *endpoint.Spec.Cache.Enabled {
			deployment.Spec.Template.Spec.Volumes = append(deployment.Spec.Template.Spec.Volumes, corev1.Volume{
				Name: "model-cache",
				VolumeSource: corev1.VolumeSource{
					PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
						ClaimName: fmt.Sprintf("%s-cache", endpoint.Name),
					},
				},
			})
		}
		
		return nil
	})
	
	return err
}

// reconcileService creates or updates the Service
func (r *AIMEndpointReconciler) reconcileService(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      endpoint.Name,
			Namespace: endpoint.Namespace,
		},
	}
	
	_, err := ctrl.CreateOrUpdate(ctx, r.Client, service, func() error {
		service.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-endpoint",
			"app.kubernetes.io/instance":  endpoint.Name,
			"app.kubernetes.io/component": "service",
		}
		
		service.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(endpoint, aimv1alpha1.GroupVersion.WithKind("AIMEndpoint")),
		}
		
		service.Spec = corev1.ServiceSpec{
			Selector: map[string]string{
				"app.kubernetes.io/name":     "aim-endpoint",
				"app.kubernetes.io/instance": endpoint.Name,
			},
			Ports: []corev1.ServicePort{
				{
					Name:       "http",
					Port:       8000,
					TargetPort: intstr.FromInt(8000),
					Protocol:   corev1.ProtocolTCP,
				},
			},
		}
		
		// Set service type
		if endpoint.Spec.Service.Type != "" {
			service.Spec.Type = corev1.ServiceType(endpoint.Spec.Service.Type)
		}
		
		// Set annotations
		if endpoint.Spec.Service.Annotations != nil {
			service.Annotations = endpoint.Spec.Service.Annotations
		}
		
		return nil
	})
	
	return err
}

// reconcileHPA creates or updates the HorizontalPodAutoscaler
func (r *AIMEndpointReconciler) reconcileHPA(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	hpa := &autoscalingv2.HorizontalPodAutoscaler{
		ObjectMeta: metav1.ObjectMeta{
			Name:      endpoint.Name,
			Namespace: endpoint.Namespace,
		},
	}
	
	_, err := ctrl.CreateOrUpdate(ctx, r.Client, hpa, func() error {
		hpa.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-endpoint",
			"app.kubernetes.io/instance":  endpoint.Name,
			"app.kubernetes.io/component": "autoscaler",
		}
		
		hpa.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(endpoint, aimv1alpha1.GroupVersion.WithKind("AIMEndpoint")),
		}
		
		hpa.Spec = autoscalingv2.HorizontalPodAutoscalerSpec{
			ScaleTargetRef: autoscalingv2.CrossVersionObjectReference{
				APIVersion: "apps/v1",
				Kind:       "Deployment",
				Name:       endpoint.Name,
			},
			MinReplicas: endpoint.Spec.Scaling.MinReplicas,
			MaxReplicas: *endpoint.Spec.Scaling.MaxReplicas,
		}
		
		// Add metrics
		var metrics []autoscalingv2.MetricSpec
		
		if endpoint.Spec.Scaling.TargetCPUUtilization != nil {
			metrics = append(metrics, autoscalingv2.MetricSpec{
				Type: autoscalingv2.ResourceMetricSourceType,
				Resource: &autoscalingv2.ResourceMetricSource{
					Name: corev1.ResourceCPU,
					Target: autoscalingv2.MetricTarget{
						Type:               autoscalingv2.UtilizationMetricType,
						AverageUtilization: endpoint.Spec.Scaling.TargetCPUUtilization,
					},
				},
			})
		}
		
		if endpoint.Spec.Scaling.TargetMemoryUtilization != nil {
			metrics = append(metrics, autoscalingv2.MetricSpec{
				Type: autoscalingv2.ResourceMetricSourceType,
				Resource: &autoscalingv2.ResourceMetricSource{
					Name: corev1.ResourceMemory,
					Target: autoscalingv2.MetricTarget{
						Type:               autoscalingv2.UtilizationMetricType,
						AverageUtilization: endpoint.Spec.Scaling.TargetMemoryUtilization,
					},
				},
			})
		}
		
		hpa.Spec.Metrics = metrics
		
		return nil
	})
	
	return err
}

// reconcileMonitoring creates or updates monitoring resources
func (r *AIMEndpointReconciler) reconcileMonitoring(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	// This would create ServiceMonitor and PrometheusRule resources
	// Implementation depends on the monitoring stack being used
	return nil
}

// updateStatus updates the endpoint status
func (r *AIMEndpointReconciler) updateStatus(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) error {
	// Get deployment status
	deployment := &appsv1.Deployment{}
	err := r.Get(ctx, types.NamespacedName{Name: endpoint.Name, Namespace: endpoint.Namespace}, deployment)
	if err != nil && !errors.IsNotFound(err) {
		return err
	}
	
	// Get service status
	service := &corev1.Service{}
	err = r.Get(ctx, types.NamespacedName{Name: endpoint.Name, Namespace: endpoint.Namespace}, service)
	if err != nil && !errors.IsNotFound(err) {
		return err
	}
	
	// Update status
	endpoint.Status.ObservedGeneration = endpoint.Generation
	
	if deployment.Status.ReadyReplicas > 0 {
		endpoint.Status.Phase = "Ready"
		endpoint.Status.Conditions = []metav1.Condition{
			{
				Type:               "Ready",
				Status:             metav1.ConditionTrue,
				Reason:             "DeploymentReady",
				Message:            "AIMEndpoint is ready",
				LastTransitionTime: metav1.Now(),
			},
		}
	} else {
		endpoint.Status.Phase = "Pending"
		endpoint.Status.Conditions = []metav1.Condition{
			{
				Type:               "Ready",
				Status:             metav1.ConditionFalse,
				Reason:             "DeploymentNotReady",
				Message:            "Deployment is not ready",
				LastTransitionTime: metav1.Now(),
			},
		}
	}
	
	// Update replica status
	if deployment.Status.Replicas > 0 {
		endpoint.Status.Replicas = &aimv1alpha1.ReplicaStatus{
			Current:   &deployment.Status.Replicas,
			Desired:   deployment.Spec.Replicas,
			Ready:     &deployment.Status.ReadyReplicas,
			Available: &deployment.Status.AvailableReplicas,
		}
	}
	
	// Update endpoint status
	if service.Spec.ClusterIP != "" {
		endpoint.Status.Endpoints = &aimv1alpha1.EndpointStatus{
			Internal: fmt.Sprintf("%s.%s.svc.cluster.local:8000", service.Name, service.Namespace),
		}
		
		if service.Spec.Type == corev1.ServiceTypeLoadBalancer {
			// This would be updated when LoadBalancer IP is assigned
			endpoint.Status.Endpoints.LoadBalancer = service.Status.LoadBalancer.Ingress[0].IP
		}
	}
	
	return r.Status().Update(ctx, endpoint)
}

// handleDeletion handles the deletion of the endpoint
func (r *AIMEndpointReconciler) handleDeletion(ctx context.Context, endpoint *aimv1alpha1.AIMEndpoint) (ctrl.Result, error) {
	// Remove finalizer
	endpoint.Finalizers = removeString(endpoint.Finalizers, "aimendpoint.aim.engine.amd.com/finalizer")
	if err := r.Update(ctx, endpoint); err != nil {
		return ctrl.Result{}, err
	}
	
	return ctrl.Result{}, nil
}

// Helper functions
func (r *AIMEndpointReconciler) getImage(endpoint *aimv1alpha1.AIMEndpoint) string {
	if endpoint.Spec.Image.Repository != "" {
		tag := "latest"
		if endpoint.Spec.Image.Tag != "" {
			tag = endpoint.Spec.Image.Tag
		}
		return fmt.Sprintf("%s:%s", endpoint.Spec.Image.Repository, tag)
	}
	
	// Default image based on backend
	backend := "vllm"
	if endpoint.Status.SelectedRecipe != nil {
		backend = endpoint.Status.SelectedRecipe.Backend
	}
	
	return fmt.Sprintf("ghcr.io/aim-engine/%s-server:latest", backend)
}

func (r *AIMEndpointReconciler) getResourceRequirements(endpoint *aimv1alpha1.AIMEndpoint) corev1.ResourceRequirements {
	requests := corev1.ResourceList{}
	limits := corev1.ResourceList{}
	
	// Set GPU requirements
	if endpoint.Status.SelectedRecipe != nil && endpoint.Status.SelectedRecipe.GPUCount != nil {
		requests["amd.com/gpu"] = resource.MustParse(strconv.Itoa(int(*endpoint.Status.SelectedRecipe.GPUCount)))
		limits["amd.com/gpu"] = resource.MustParse(strconv.Itoa(int(*endpoint.Status.SelectedRecipe.GPUCount)))
	}
	
	// Set CPU and memory requirements
	if endpoint.Spec.Resources.CPU != "" {
		requests[corev1.ResourceCPU] = resource.MustParse(endpoint.Spec.Resources.CPU)
	}
	if endpoint.Spec.Resources.Memory != "" {
		requests[corev1.ResourceMemory] = resource.MustParse(endpoint.Spec.Resources.Memory)
	}
	if endpoint.Spec.Resources.CPULimit != "" {
		limits[corev1.ResourceCPU] = resource.MustParse(endpoint.Spec.Resources.CPULimit)
	}
	if endpoint.Spec.Resources.MemoryLimit != "" {
		limits[corev1.ResourceMemory] = resource.MustParse(endpoint.Spec.Resources.MemoryLimit)
	}
	
	return corev1.ResourceRequirements{
		Requests: requests,
		Limits:   limits,
	}
}

func (r *AIMEndpointReconciler) getEnvironmentVariables(endpoint *aimv1alpha1.AIMEndpoint) []corev1.EnvVar {
	envVars := []corev1.EnvVar{
		{
			Name:  "MODEL_ID",
			Value: endpoint.Spec.Model.ID,
		},
	}
	
	if endpoint.Spec.Model.Version != "" {
		envVars = append(envVars, corev1.EnvVar{
			Name:  "MODEL_VERSION",
			Value: endpoint.Spec.Model.Version,
		})
	}
	
	if endpoint.Status.SelectedRecipe != nil {
		envVars = append(envVars, corev1.EnvVar{
			Name:  "PRECISION",
			Value: endpoint.Status.SelectedRecipe.Precision,
		})
	}
	
	return envVars
}

func containsString(slice []string, str string) bool {
	for _, item := range slice {
		if item == str {
			return true
		}
	}
	return false
}

func removeString(slice []string, str string) []string {
	for i, item := range slice {
		if item == str {
			return append(slice[:i], slice[i+1:]...)
		}
	}
	return slice
} 