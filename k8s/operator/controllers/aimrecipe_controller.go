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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	aimv1alpha1 "github.com/aim-engine/operator/api/v1alpha1"
)

// AIMRecipeReconciler reconciles a AIMRecipe object
type AIMRecipeReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimrecipes,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimrecipes/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimrecipes/finalizers,verbs=update
//+kubebuilder:rbac:groups=aim.engine.amd.com,resources=aimendpoints,verbs=get;list;watch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
func (r *AIMRecipeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the AIMRecipe instance
	aimRecipe := &aimv1alpha1.AIMRecipe{}
	err := r.Get(ctx, req.NamespacedName, aimRecipe)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			logger.Info("AIMRecipe resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the request.
		logger.Error(err, "Failed to get AIMRecipe")
		return ctrl.Result{}, err
	}

	// Check if the resource is being deleted
	if !aimRecipe.DeletionTimestamp.IsZero() {
		return r.handleDeletion(ctx, aimRecipe)
	}

	// Add finalizer if not present
	if !containsString(aimRecipe.Finalizers, "aimrecipe.aim.engine.amd.com/finalizer") {
		aimRecipe.Finalizers = append(aimRecipe.Finalizers, "aimrecipe.aim.engine.amd.com/finalizer")
		if err := r.Update(ctx, aimRecipe); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Validate recipe configuration
	if err := r.validateRecipe(ctx, aimRecipe); err != nil {
		logger.Error(err, "Recipe validation failed")
		aimRecipe.Status.Phase = "Invalid"
		aimRecipe.Status.Conditions = []metav1.Condition{
			{
				Type:               "Valid",
				Status:             metav1.ConditionFalse,
				Reason:             "ValidationFailed",
				Message:            fmt.Sprintf("Recipe validation failed: %v", err),
				LastTransitionTime: metav1.Now(),
			},
		}
		r.Status().Update(ctx, aimRecipe)
		return ctrl.Result{RequeueAfter: time.Minute * 5}, err
	}

	// Update usage statistics
	if err := r.updateUsageStatistics(ctx, aimRecipe); err != nil {
		logger.Error(err, "Failed to update usage statistics")
		return ctrl.Result{}, err
	}

	// Update status
	aimRecipe.Status.Phase = "Ready"
	aimRecipe.Status.Conditions = []metav1.Condition{
		{
			Type:               "Valid",
			Status:             metav1.ConditionTrue,
			Reason:             "ValidationSucceeded",
			Message:            "Recipe is valid and ready for use",
			LastTransitionTime: metav1.Now(),
		},
	}
	aimRecipe.Status.ObservedGeneration = aimRecipe.Generation

	if err := r.Status().Update(ctx, aimRecipe); err != nil {
		logger.Error(err, "Failed to update status")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled AIMRecipe")
	return ctrl.Result{RequeueAfter: time.Minute * 10}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *AIMRecipeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&aimv1alpha1.AIMRecipe{}).
		Complete(r)
}

// validateRecipe validates the recipe configuration
func (r *AIMRecipeReconciler) validateRecipe(ctx context.Context, recipe *aimv1alpha1.AIMRecipe) error {
	// Validate hardware platform
	validHardware := []string{"MI300X", "MI325X", "MI355X", "MI250", "MI210"}
	hardwareValid := false
	for _, hw := range validHardware {
		if recipe.Spec.Hardware == hw {
			hardwareValid = true
			break
		}
	}
	if !hardwareValid {
		return fmt.Errorf("invalid hardware platform: %s", recipe.Spec.Hardware)
	}

	// Validate precision
	validPrecisions := []string{"bfloat16", "float16", "float8", "int8", "int4"}
	precisionValid := false
	for _, p := range validPrecisions {
		if recipe.Spec.Precision == p {
			precisionValid = true
			break
		}
	}
	if !precisionValid {
		return fmt.Errorf("invalid precision: %s", recipe.Spec.Precision)
	}

	// Validate backend
	validBackends := []string{"vllm", "sglang"}
	backendValid := false
	for _, b := range validBackends {
		if recipe.Spec.Backend == b {
			backendValid = true
			break
		}
	}
	if !backendValid {
		return fmt.Errorf("invalid backend: %s", recipe.Spec.Backend)
	}

	// Validate configurations
	if len(recipe.Spec.Configurations) == 0 {
		return fmt.Errorf("at least one GPU configuration is required")
	}

	enabledConfigs := 0
	for i, config := range recipe.Spec.Configurations {
		if config.GPUCount < 1 || config.GPUCount > 8 {
			return fmt.Errorf("configuration %d: GPU count must be between 1 and 8", i)
		}
		if config.Enabled {
			enabledConfigs++
		}
	}

	if enabledConfigs == 0 {
		return fmt.Errorf("at least one GPU configuration must be enabled")
	}

	return nil
}

// updateUsageStatistics updates the usage statistics for the recipe
func (r *AIMRecipeReconciler) updateUsageStatistics(ctx context.Context, recipe *aimv1alpha1.AIMRecipe) error {
	// Find all endpoints using this recipe
	endpoints := &aimv1alpha1.AIMEndpointList{}
	err := r.List(ctx, endpoints)
	if err != nil {
		return err
	}

	endpointCount := int32(0)
	var lastUsed *metav1.Time

	for _, endpoint := range endpoints.Items {
		if endpoint.Status.SelectedRecipe != nil && endpoint.Status.SelectedRecipe.Name == recipe.Name {
			endpointCount++
			if lastUsed == nil || endpoint.CreationTimestamp.After(lastUsed.Time) {
				lastUsed = &endpoint.CreationTimestamp
			}
		}
	}

	// Update usage status
	recipe.Status.Usage = &aimv1alpha1.UsageStatus{
		EndpointCount: &endpointCount,
		LastUsed:      lastUsed,
	}

	return nil
}

// handleDeletion handles the deletion of the recipe
func (r *AIMRecipeReconciler) handleDeletion(ctx context.Context, recipe *aimv1alpha1.AIMRecipe) (ctrl.Result, error) {
	// Check if any endpoints are still using this recipe
	endpoints := &aimv1alpha1.AIMEndpointList{}
	err := r.List(ctx, endpoints)
	if err != nil {
		return ctrl.Result{}, err
	}

	usingEndpoints := []string{}
	for _, endpoint := range endpoints.Items {
		if endpoint.Status.SelectedRecipe != nil && endpoint.Status.SelectedRecipe.Name == recipe.Name {
			usingEndpoints = append(usingEndpoints, fmt.Sprintf("%s/%s", endpoint.Namespace, endpoint.Name))
		}
	}

	if len(usingEndpoints) > 0 {
		// Recipe is still in use, prevent deletion
		recipe.Status.Phase = "DeletionBlocked"
		recipe.Status.Conditions = []metav1.Condition{
			{
				Type:               "DeletionBlocked",
				Status:             metav1.ConditionTrue,
				Reason:             "EndpointsStillUsing",
				Message:            fmt.Sprintf("Cannot delete recipe: still in use by endpoints: %v", usingEndpoints),
				LastTransitionTime: metav1.Now(),
			},
		}
		r.Status().Update(ctx, recipe)
		return ctrl.Result{RequeueAfter: time.Minute * 5}, nil
	}

	// Remove finalizer
	recipe.Finalizers = removeString(recipe.Finalizers, "aimrecipe.aim.engine.amd.com/finalizer")
	if err := r.Update(ctx, recipe); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
} 