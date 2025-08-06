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
	"time"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	aimv1alpha1 "github.com/aim-engine/operator/api/v1alpha1"
	corev1 "k8s.io/api/core/v1"
)

// AIMCacheReconciler reconciles a AIMCache object
type AIMCacheReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimcaches,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimcaches/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimcaches/finalizers,verbs=update
//+kubebuilder:rbac:groups=core,resources=persistentvolumeclaims,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
func (r *AIMCacheReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the AIMCache instance
	aimCache := &aimv1alpha1.AIMCache{}
	err := r.Get(ctx, req.NamespacedName, aimCache)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			logger.Info("AIMCache resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the request.
		logger.Error(err, "Failed to get AIMCache")
		return ctrl.Result{}, err
	}

	// Check if the resource is being deleted
	if !aimCache.DeletionTimestamp.IsZero() {
		return r.handleDeletion(ctx, aimCache)
	}

	// Add finalizer if not present
	if !containsString(aimCache.Finalizers, "aimcache.aim.engine.amd.com/finalizer") {
		aimCache.Finalizers = append(aimCache.Finalizers, "aimcache.aim.engine.amd.com/finalizer")
		if err := r.Update(ctx, aimCache); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Create or update PVC
	if err := r.reconcilePVC(ctx, aimCache); err != nil {
		logger.Error(err, "Failed to reconcile PVC")
		return ctrl.Result{}, err
	}

	// Update storage status
	if err := r.updateStorageStatus(ctx, aimCache); err != nil {
		logger.Error(err, "Failed to update storage status")
		return ctrl.Result{}, err
	}

	// Update cached models status
	if err := r.updateCachedModelsStatus(ctx, aimCache); err != nil {
		logger.Error(err, "Failed to update cached models status")
		return ctrl.Result{}, err
	}

	// Run cleanup if enabled
	if aimCache.Spec.Cleanup != nil && aimCache.Spec.Cleanup.Enabled != nil && *aimCache.Spec.Cleanup.Enabled {
		if err := r.runCleanup(ctx, aimCache); err != nil {
			logger.Error(err, "Failed to run cleanup")
			return ctrl.Result{}, err
		}
	}

	// Update status
	aimCache.Status.Phase = "Ready"
	aimCache.Status.Conditions = []metav1.Condition{
		{
			Type:               "Ready",
			Status:             metav1.ConditionTrue,
			Reason:             "CacheReady",
			Message:            "AIMCache is ready",
			LastTransitionTime: metav1.Now(),
		},
	}
	aimCache.Status.ObservedGeneration = aimCache.Generation

	if err := r.Status().Update(ctx, aimCache); err != nil {
		logger.Error(err, "Failed to update status")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled AIMCache")
	return ctrl.Result{RequeueAfter: time.Minute * 15}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *AIMCacheReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&aimv1alpha1.AIMCache{}).
		Owns(&corev1.PersistentVolumeClaim{}).
		Complete(r)
}

// reconcilePVC creates or updates the PersistentVolumeClaim for the cache
func (r *AIMCacheReconciler) reconcilePVC(ctx context.Context, cache *aimv1alpha1.AIMCache) error {
	pvc := &corev1.PersistentVolumeClaim{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-storage", cache.Name),
			Namespace: cache.Namespace,
		},
	}

	_, err := ctrl.CreateOrUpdate(ctx, r.Client, pvc, func() error {
		pvc.Labels = map[string]string{
			"app.kubernetes.io/name":      "aim-cache",
			"app.kubernetes.io/instance":  cache.Name,
			"app.kubernetes.io/component": "storage",
		}

		pvc.OwnerReferences = []metav1.OwnerReference{
			*metav1.NewControllerRef(cache, aimv1alpha1.GroupVersion.WithKind("AIMCache")),
		}

		// Set access mode
		accessMode := corev1.ReadWriteOnce
		if cache.Spec.Storage.AccessMode != "" {
			accessMode = corev1.PersistentVolumeAccessMode(cache.Spec.Storage.AccessMode)
		}

		pvc.Spec = corev1.PersistentVolumeClaimSpec{
			AccessModes: []corev1.PersistentVolumeAccessMode{accessMode},
			Resources: corev1.ResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceStorage: resource.MustParse(cache.Spec.Storage.Size),
				},
			},
		}

		// Set storage class if specified
		if cache.Spec.Storage.StorageClass != "" {
			pvc.Spec.StorageClassName = &cache.Spec.Storage.StorageClass
		}

		return nil
	})

	return err
}

// updateStorageStatus updates the storage status information
func (r *AIMCacheReconciler) updateStorageStatus(ctx context.Context, cache *aimv1alpha1.AIMCache) error {
	pvc := &corev1.PersistentVolumeClaim{}
	err := r.Get(ctx, types.NamespacedName{
		Name:      fmt.Sprintf("%s-storage", cache.Name),
		Namespace: cache.Namespace,
	}, pvc)
	if err != nil {
		if errors.IsNotFound(err) {
			// PVC not found, clear storage status
			cache.Status.Storage = nil
			return nil
		}
		return err
	}

	// Calculate storage usage
	totalSize := pvc.Spec.Resources.Requests[corev1.ResourceStorage]
	usedSize := resource.MustParse("0") // This would be calculated from actual usage
	availableSize := totalSize.DeepCopy()
	availableSize.Sub(usedSize)

	usagePercentage := float64(usedSize.Value()) / float64(totalSize.Value()) * 100

	cache.Status.Storage = &aimv1alpha1.StorageStatus{
		TotalSize:        totalSize.String(),
		UsedSize:         usedSize.String(),
		AvailableSize:    availableSize.String(),
		UsagePercentage:  &usagePercentage,
		PVCName:          pvc.Name,
		PVCPhase:         string(pvc.Status.Phase),
	}

	return nil
}

// updateCachedModelsStatus updates the cached models status
func (r *AIMCacheReconciler) updateCachedModelsStatus(ctx context.Context, cache *aimv1alpha1.AIMCache) error {
	// This would typically query the actual cache storage to determine what models are cached
	// For now, we'll simulate this based on the configured models

	var cachedModels []aimv1alpha1.CachedModelStatus
	totalModels := int32(0)
	activeModels := int32(0)

	for _, model := range cache.Spec.Models {
		// Simulate cached model status
		cachedModel := aimv1alpha1.CachedModelStatus{
			ID:        model.ID,
			Size:      "10Gi", // This would be calculated from actual storage
			CachedAt:  &metav1.Time{Time: time.Now().Add(-time.Hour * 24)}, // Simulated
			Status:    "cached",
			AccessCount: func() *int64 { v := int64(0); return &v }(), // This would be tracked from actual usage
		}

		// Simulate last accessed time
		lastAccessed := metav1.Time{Time: time.Now().Add(-time.Hour * 2)}
		cachedModel.LastAccessed = &lastAccessed

		cachedModels = append(cachedModels, cachedModel)
		totalModels++

		// Consider model active if accessed in last 24 hours
		if time.Since(lastAccessed.Time) < time.Hour*24 {
			activeModels++
		}
	}

	cache.Status.CachedModels = cachedModels
	cache.Status.Usage = &aimv1alpha1.CacheUsageStatus{
		TotalModels:  &totalModels,
		ActiveModels: &activeModels,
		LastCleanup:  &metav1.Time{Time: time.Now().Add(-time.Hour * 6)}, // Simulated
		NextCleanup:  &metav1.Time{Time: time.Now().Add(time.Hour * 18)}, // Simulated
	}

	return nil
}

// runCleanup runs the cleanup process for the cache
func (r *AIMCacheReconciler) runCleanup(ctx context.Context, cache *aimv1alpha1.AIMCache) error {
	if cache.Spec.Cleanup == nil {
		return nil
	}

	// Check if cleanup is scheduled
	if cache.Spec.Cleanup.Schedule != "" {
		// This would use a cron parser to check if cleanup should run now
		// For simplicity, we'll run cleanup every reconciliation if enabled
		logger := log.FromContext(ctx)
		logger.Info("Running scheduled cache cleanup")
	}

	// Cleanup based on age
	if cache.Spec.Cleanup.MaxAge != "" {
		// Parse max age and remove old models
		// This would remove models older than the specified age
	}

	// Cleanup based on free space
	if cache.Spec.Cleanup.MinFreeSpace != "" {
		// Ensure minimum free space is maintained
		// This would remove models until minimum free space is available
	}

	// Update cleanup timestamps
	now := metav1.Now()
	if cache.Status.Usage != nil {
		cache.Status.Usage.LastCleanup = &now
		// Calculate next cleanup time based on schedule
		nextCleanup := metav1.Time{Time: now.Time.Add(time.Hour * 24)}
		cache.Status.Usage.NextCleanup = &nextCleanup
	}

	return nil
}

// handleDeletion handles the deletion of the cache
func (r *AIMCacheReconciler) handleDeletion(ctx context.Context, cache *aimv1alpha1.AIMCache) (ctrl.Result, error) {
	// Check if any endpoints are using this cache
	endpoints := &aimv1alpha1.AIMEndpointList{}
	err := r.List(ctx, endpoints)
	if err != nil {
		return ctrl.Result{}, err
	}

	usingEndpoints := []string{}
	for _, endpoint := range endpoints.Items {
		if endpoint.Spec.Cache.Enabled != nil && *endpoint.Spec.Cache.Enabled {
			// Check if this endpoint is using the cache
			// This would require more sophisticated logic to determine cache usage
			usingEndpoints = append(usingEndpoints, fmt.Sprintf("%s/%s", endpoint.Namespace, endpoint.Name))
		}
	}

	if len(usingEndpoints) > 0 {
		// Cache is still in use, prevent deletion
		cache.Status.Phase = "DeletionBlocked"
		cache.Status.Conditions = []metav1.Condition{
			{
				Type:               "DeletionBlocked",
				Status:             metav1.ConditionTrue,
				Reason:             "EndpointsStillUsing",
				Message:            fmt.Sprintf("Cannot delete cache: still in use by endpoints: %v", usingEndpoints),
				LastTransitionTime: metav1.Now(),
			},
		}
		r.Status().Update(ctx, cache)
		return ctrl.Result{RequeueAfter: time.Minute * 5}, nil
	}

	// Remove finalizer
	cache.Finalizers = removeString(cache.Finalizers, "aimcache.aim.engine.amd.com/finalizer")
	if err := r.Update(ctx, cache); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
} 