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

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// AIMEndpointSpec defines the desired state of AIMEndpoint
type AIMEndpointSpec struct {
	// Model configuration
	Model ModelSpec `json:"model"`

	// Recipe selection configuration
	Recipe RecipeSpec `json:"recipe,omitempty"`

	// Resource configuration
	Resources ResourceSpec `json:"resources,omitempty"`

	// Scaling configuration
	Scaling ScalingSpec `json:"scaling,omitempty"`

	// Service configuration
	Service ServiceSpec `json:"service,omitempty"`

	// Monitoring configuration
	Monitoring MonitoringSpec `json:"monitoring,omitempty"`

	// Cache configuration
	Cache CacheSpec `json:"cache,omitempty"`

	// Security configuration
	Security SecuritySpec `json:"security,omitempty"`

	// Deployment configuration
	Deployment DeploymentSpec `json:"deployment,omitempty"`

	// Image configuration
	Image ImageSpec `json:"image,omitempty"`
}

// ModelSpec defines the model configuration
type ModelSpec struct {
	// HuggingFace model ID
	ID string `json:"id"`

	// Model version (optional)
	Version string `json:"version,omitempty"`

	// Specific model revision (optional)
	Revision string `json:"revision,omitempty"`
}

// RecipeSpec defines the recipe selection configuration
type RecipeSpec struct {
	// Enable automatic recipe selection
	AutoSelect bool `json:"autoSelect,omitempty"`

	// Manual GPU count override
	GPUCount *int32 `json:"gpuCount,omitempty"`

	// Manual precision override
	Precision string `json:"precision,omitempty"`

	// Manual backend override
	Backend string `json:"backend,omitempty"`

	// Reference to custom AIMRecipe
	CustomRecipe *CustomRecipeRef `json:"customRecipe,omitempty"`
}

// CustomRecipeRef defines a reference to a custom recipe
type CustomRecipeRef struct {
	// Name of the custom recipe
	Name string `json:"name"`

	// Namespace of the custom recipe
	Namespace string `json:"namespace,omitempty"`
}

// ResourceSpec defines the resource configuration
type ResourceSpec struct {
	// Number of GPUs to allocate
	GPUCount *int32 `json:"gpuCount,omitempty"`

	// Memory request
	Memory string `json:"memory,omitempty"`

	// CPU request
	CPU string `json:"cpu,omitempty"`

	// Memory limit
	MemoryLimit string `json:"memoryLimit,omitempty"`

	// CPU limit
	CPULimit string `json:"cpuLimit,omitempty"`
}

// ScalingSpec defines the scaling configuration
type ScalingSpec struct {
	// Minimum number of replicas
	MinReplicas *int32 `json:"minReplicas,omitempty"`

	// Maximum number of replicas
	MaxReplicas *int32 `json:"maxReplicas,omitempty"`

	// Target CPU utilization percentage
	TargetCPUUtilization *int32 `json:"targetCPUUtilization,omitempty"`

	// Target memory utilization percentage
	TargetMemoryUtilization *int32 `json:"targetMemoryUtilization,omitempty"`

	// Target GPU utilization percentage
	TargetGPUUtilization *int32 `json:"targetGPUUtilization,omitempty"`

	// Scale down delay in seconds
	ScaleDownDelay *int32 `json:"scaleDownDelay,omitempty"`

	// Scale up delay in seconds
	ScaleUpDelay *int32 `json:"scaleUpDelay,omitempty"`
}

// ServiceSpec defines the service configuration
type ServiceSpec struct {
	// Service type
	Type string `json:"type,omitempty"`

	// Service port
	Port *int32 `json:"port,omitempty"`

	// Target port
	TargetPort *int32 `json:"targetPort,omitempty"`

	// Service annotations
	Annotations map[string]string `json:"annotations,omitempty"`

	// Load balancer IP (for LoadBalancer type)
	LoadBalancerIP string `json:"loadBalancerIP,omitempty"`
}

// MonitoringSpec defines the monitoring configuration
type MonitoringSpec struct {
	// Enable monitoring
	Enabled *bool `json:"enabled,omitempty"`

	// Prometheus configuration
	Prometheus *PrometheusSpec `json:"prometheus,omitempty"`

	// Grafana configuration
	Grafana *GrafanaSpec `json:"grafana,omitempty"`
}

// PrometheusSpec defines Prometheus monitoring configuration
type PrometheusSpec struct {
	// Enable Prometheus monitoring
	Enabled *bool `json:"enabled,omitempty"`

	// Scrape interval
	Interval string `json:"interval,omitempty"`

	// Metrics path
	Path string `json:"path,omitempty"`
}

// GrafanaSpec defines Grafana configuration
type GrafanaSpec struct {
	// Enable Grafana dashboard
	Enabled *bool `json:"enabled,omitempty"`

	// Dashboard name
	Dashboard string `json:"dashboard,omitempty"`
}

// CacheSpec defines the cache configuration
type CacheSpec struct {
	// Enable model caching
	Enabled *bool `json:"enabled,omitempty"`

	// Storage class for cache
	StorageClass string `json:"storageClass,omitempty"`

	// Cache size
	Size string `json:"size,omitempty"`

	// Access mode
	AccessMode string `json:"accessMode,omitempty"`
}

// SecuritySpec defines the security configuration
type SecuritySpec struct {
	// Service account configuration
	ServiceAccount *ServiceAccountSpec `json:"serviceAccount,omitempty"`

	// Pod security context
	PodSecurityContext *PodSecurityContextSpec `json:"podSecurityContext,omitempty"`
}

// ServiceAccountSpec defines service account configuration
type ServiceAccountSpec struct {
	// Create service account
	Create *bool `json:"create,omitempty"`

	// Service account name
	Name string `json:"name,omitempty"`
}

// PodSecurityContextSpec defines pod security context
type PodSecurityContextSpec struct {
	// Run as user ID
	RunAsUser *int64 `json:"runAsUser,omitempty"`

	// Run as group ID
	RunAsGroup *int64 `json:"runAsGroup,omitempty"`

	// File system group ID
	FSGroup *int64 `json:"fsGroup,omitempty"`
}

// DeploymentSpec defines the deployment configuration
type DeploymentSpec struct {
	// Deployment strategy
	Strategy *DeploymentStrategySpec `json:"strategy,omitempty"`

	// Canary deployment configuration
	Canary *CanarySpec `json:"canary,omitempty"`
}

// DeploymentStrategySpec defines deployment strategy
type DeploymentStrategySpec struct {
	// Strategy type
	Type string `json:"type,omitempty"`

	// Rolling update configuration
	RollingUpdate *RollingUpdateSpec `json:"rollingUpdate,omitempty"`
}

// RollingUpdateSpec defines rolling update configuration
type RollingUpdateSpec struct {
	// Maximum surge
	MaxSurge *int32 `json:"maxSurge,omitempty"`

	// Maximum unavailable
	MaxUnavailable *int32 `json:"maxUnavailable,omitempty"`
}

// CanarySpec defines canary deployment configuration
type CanarySpec struct {
	// Enable canary deployment
	Enabled *bool `json:"enabled,omitempty"`

	// Traffic split percentage
	TrafficSplit *int32 `json:"trafficSplit,omitempty"`

	// Canary duration in seconds
	Duration *int32 `json:"duration,omitempty"`
}

// ImageSpec defines the image configuration
type ImageSpec struct {
	// Image repository
	Repository string `json:"repository,omitempty"`

	// Image tag
	Tag string `json:"tag,omitempty"`

	// Image pull policy
	PullPolicy string `json:"pullPolicy,omitempty"`

	// Image pull secrets
	PullSecrets []string `json:"pullSecrets,omitempty"`
}

// AIMEndpointStatus defines the observed state of AIMEndpoint
type AIMEndpointStatus struct {
	// Conditions represent the latest available observations of an object's state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the last observed generation
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// Current phase of the endpoint
	Phase string `json:"phase,omitempty"`

	// Selected recipe information
	SelectedRecipe *SelectedRecipeStatus `json:"selectedRecipe,omitempty"`

	// Service endpoints
	Endpoints *EndpointStatus `json:"endpoints,omitempty"`

	// Current replica information
	Replicas *ReplicaStatus `json:"replicas,omitempty"`

	// Performance metrics
	Metrics *MetricsStatus `json:"metrics,omitempty"`
}

// SelectedRecipeStatus defines selected recipe information
type SelectedRecipeStatus struct {
	// Recipe name
	Name string `json:"name,omitempty"`

	// Selected GPU count
	GPUCount *int32 `json:"gpuCount,omitempty"`

	// Selected precision
	Precision string `json:"precision,omitempty"`

	// Selected backend
	Backend string `json:"backend,omitempty"`
}

// EndpointStatus defines service endpoints
type EndpointStatus struct {
	// Internal endpoint
	Internal string `json:"internal,omitempty"`

	// External endpoint
	External string `json:"external,omitempty"`

	// Load balancer endpoint
	LoadBalancer string `json:"loadBalancer,omitempty"`
}

// ReplicaStatus defines current replica information
type ReplicaStatus struct {
	// Current number of replicas
	Current *int32 `json:"current,omitempty"`

	// Desired number of replicas
	Desired *int32 `json:"desired,omitempty"`

	// Number of ready replicas
	Ready *int32 `json:"ready,omitempty"`

	// Number of available replicas
	Available *int32 `json:"available,omitempty"`
}

// MetricsStatus defines performance metrics
type MetricsStatus struct {
	// Average latency in milliseconds
	Latency *float64 `json:"latency,omitempty"`

	// Requests per second
	Throughput *float64 `json:"throughput,omitempty"`

	// GPU utilization percentage
	GPUUtilization *float64 `json:"gpuUtilization,omitempty"`

	// Memory utilization percentage
	MemoryUtilization *float64 `json:"memoryUtilization,omitempty"`

	// CPU utilization percentage
	CPUUtilization *float64 `json:"cpuUtilization,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Model",type="string",JSONPath=".spec.model.id"
//+kubebuilder:printcolumn:name="Recipe",type="string",JSONPath=".status.selectedRecipe.name"
//+kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
//+kubebuilder:printcolumn:name="Replicas",type="string",JSONPath=".status.replicas.current"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// AIMEndpoint is the Schema for the aimendpoints API
type AIMEndpoint struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AIMEndpointSpec   `json:"spec,omitempty"`
	Status AIMEndpointStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// AIMEndpointList contains a list of AIMEndpoint
type AIMEndpointList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AIMEndpoint `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AIMEndpoint{}, &AIMEndpointList{})
} 