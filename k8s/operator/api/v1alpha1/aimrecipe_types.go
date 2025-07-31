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

// AIMRecipeSpec defines the desired state of AIMRecipe
type AIMRecipeSpec struct {
	// HuggingFace model ID
	ModelID string `json:"modelId"`

	// Target hardware platform
	Hardware string `json:"hardware"`

	// Precision format
	Precision string `json:"precision"`

	// Serving backend
	Backend string `json:"backend"`

	// Recipe description
	Description string `json:"description,omitempty"`

	// GPU configurations
	Configurations []GPUConfiguration `json:"configurations,omitempty"`

	// Performance expectations
	Performance *PerformanceSpec `json:"performance,omitempty"`
}

// GPUConfiguration defines a GPU configuration
type GPUConfiguration struct {
	// Number of GPUs
	GPUCount int32 `json:"gpuCount"`

	// Enable this configuration
	Enabled bool `json:"enabled"`

	// Command line arguments
	Args []string `json:"args,omitempty"`

	// Environment variables
	Env []EnvVar `json:"env,omitempty"`

	// Resource requirements
	Resources *ResourceRequirements `json:"resources,omitempty"`
}

// EnvVar represents an environment variable
type EnvVar struct {
	// Environment variable name
	Name string `json:"name"`

	// Environment variable value
	Value string `json:"value,omitempty"`

	// Value from a source
	ValueFrom *EnvVarSource `json:"valueFrom,omitempty"`
}

// EnvVarSource represents a source for the value of an EnvVar
type EnvVarSource struct {
	// Selects a field of the pod
	FieldRef *ObjectFieldSelector `json:"fieldRef,omitempty"`

	// Selects a resource of the container
	ResourceFieldRef *ResourceFieldSelector `json:"resourceFieldRef,omitempty"`

	// Selects a key of a ConfigMap
	ConfigMapKeyRef *ConfigMapKeySelector `json:"configMapKeyRef,omitempty"`

	// Selects a key of a Secret
	SecretKeyRef *SecretKeySelector `json:"secretKeyRef,omitempty"`
}

// ObjectFieldSelector selects an APIVersioned field of an object
type ObjectFieldSelector struct {
	// Version of the schema the FieldPath is written in terms of
	APIVersion string `json:"apiVersion,omitempty"`

	// Path of the field to select in the specified API version
	FieldPath string `json:"fieldPath"`
}

// ResourceFieldSelector represents container resources (cpu, memory) and their output format
type ResourceFieldSelector struct {
	// Container name
	ContainerName string `json:"containerName,omitempty"`

	// Specifies the output format of the exposed resources
	Divisor string `json:"divisor,omitempty"`

	// Required: resource to select
	Resource string `json:"resource"`
}

// ConfigMapKeySelector selects a key from a ConfigMap
type ConfigMapKeySelector struct {
	// The ConfigMap to select from
	LocalObjectReference `json:",inline"`

	// The key to select
	Key string `json:"key"`

	// Specify whether the ConfigMap or its key must be defined
	Optional *bool `json:"optional,omitempty"`
}

// SecretKeySelector selects a key of a Secret
type SecretKeySelector struct {
	// The Secret to select from
	LocalObjectReference `json:",inline"`

	// The key of the secret to select from
	Key string `json:"key"`

	// Specify whether the Secret or its key must be defined
	Optional *bool `json:"optional,omitempty"`
}

// LocalObjectReference contains enough information to let you locate the referenced object inside the same namespace
type LocalObjectReference struct {
	// Name of the referent
	Name string `json:"name,omitempty"`
}

// ResourceRequirements describes the compute resource requirements
type ResourceRequirements struct {
	// Limits describes the maximum amount of compute resources allowed
	Limits map[string]string `json:"limits,omitempty"`

	// Requests describes the minimum amount of compute resources required
	Requests map[string]string `json:"requests,omitempty"`
}

// PerformanceSpec defines performance expectations
type PerformanceSpec struct {
	// Expected tokens per second
	ExpectedTokensPerSecond *int32 `json:"expectedTokensPerSecond,omitempty"`

	// Expected latency in milliseconds
	ExpectedLatencyMs *int32 `json:"expectedLatencyMs,omitempty"`

	// Maximum batch size
	MaxBatchSize *int32 `json:"maxBatchSize,omitempty"`
}

// AIMRecipeStatus defines the observed state of AIMRecipe
type AIMRecipeStatus struct {
	// Conditions represent the latest available observations of an object's state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the last observed generation
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// Current phase of the recipe
	Phase string `json:"phase,omitempty"`

	// Usage statistics
	Usage *UsageStatus `json:"usage,omitempty"`
}

// UsageStatus defines usage statistics
type UsageStatus struct {
	// Number of endpoints using this recipe
	EndpointCount *int32 `json:"endpointCount,omitempty"`

	// Last used timestamp
	LastUsed *metav1.Time `json:"lastUsed,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Model",type="string",JSONPath=".spec.modelId"
//+kubebuilder:printcolumn:name="Hardware",type="string",JSONPath=".spec.hardware"
//+kubebuilder:printcolumn:name="Precision",type="string",JSONPath=".spec.precision"
//+kubebuilder:printcolumn:name="Backend",type="string",JSONPath=".spec.backend"
//+kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// AIMRecipe is the Schema for the aimrecipes API
type AIMRecipe struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AIMRecipeSpec   `json:"spec,omitempty"`
	Status AIMRecipeStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// AIMRecipeList contains a list of AIMRecipe
type AIMRecipeList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AIMRecipe `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AIMRecipe{}, &AIMRecipeList{})
} 