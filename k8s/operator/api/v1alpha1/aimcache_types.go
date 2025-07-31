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

// AIMCacheSpec defines the desired state of AIMCache
type AIMCacheSpec struct {
	// Storage configuration
	Storage StorageSpec `json:"storage"`

	// Model cache configuration
	Models []ModelCacheSpec `json:"models,omitempty"`

	// Cleanup configuration
	Cleanup *CleanupSpec `json:"cleanup,omitempty"`
}

// StorageSpec defines storage configuration
type StorageSpec struct {
	// Storage class name
	StorageClass string `json:"storageClass,omitempty"`

	// Cache size
	Size string `json:"size"`

	// Access mode
	AccessMode string `json:"accessMode,omitempty"`

	// Mount path in containers
	MountPath string `json:"mountPath,omitempty"`
}

// ModelCacheSpec defines model cache configuration
type ModelCacheSpec struct {
	// Model ID
	ID string `json:"id"`

	// Cache priority
	Priority string `json:"priority,omitempty"`

	// Retention period
	Retention string `json:"retention,omitempty"`

	// Maximum size for this model
	MaxSize string `json:"maxSize,omitempty"`

	// Preload this model
	Preload *bool `json:"preload,omitempty"`
}

// CleanupSpec defines cleanup configuration
type CleanupSpec struct {
	// Enable cleanup
	Enabled *bool `json:"enabled,omitempty"`

	// Cleanup schedule (cron format)
	Schedule string `json:"schedule,omitempty"`

	// Maximum age for cached models
	MaxAge string `json:"maxAge,omitempty"`

	// Minimum free space to maintain
	MinFreeSpace string `json:"minFreeSpace,omitempty"`

	// Cleanup strategy
	Strategy string `json:"strategy,omitempty"`
}

// AIMCacheStatus defines the observed state of AIMCache
type AIMCacheStatus struct {
	// Conditions represent the latest available observations of an object's state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the last observed generation
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// Current phase of the cache
	Phase string `json:"phase,omitempty"`

	// Storage information
	Storage *StorageStatus `json:"storage,omitempty"`

	// Cached models
	CachedModels []CachedModelStatus `json:"cachedModels,omitempty"`

	// Usage statistics
	Usage *CacheUsageStatus `json:"usage,omitempty"`
}

// StorageStatus defines storage status
type StorageStatus struct {
	// Total size
	TotalSize string `json:"totalSize,omitempty"`

	// Used size
	UsedSize string `json:"usedSize,omitempty"`

	// Available size
	AvailableSize string `json:"availableSize,omitempty"`

	// Usage percentage
	UsagePercentage *float64 `json:"usagePercentage,omitempty"`

	// PVC name
	PVCName string `json:"pvcName,omitempty"`

	// PVC phase
	PVCPhase string `json:"pvcPhase,omitempty"`
}

// CachedModelStatus defines cached model status
type CachedModelStatus struct {
	// Model ID
	ID string `json:"id"`

	// Model size
	Size string `json:"size,omitempty"`

	// Cached timestamp
	CachedAt *metav1.Time `json:"cachedAt,omitempty"`

	// Last accessed timestamp
	LastAccessed *metav1.Time `json:"lastAccessed,omitempty"`

	// Access count
	AccessCount *int64 `json:"accessCount,omitempty"`

	// Status
	Status string `json:"status,omitempty"`
}

// CacheUsageStatus defines cache usage statistics
type CacheUsageStatus struct {
	// Total number of cached models
	TotalModels *int32 `json:"totalModels,omitempty"`

	// Number of active models
	ActiveModels *int32 `json:"activeModels,omitempty"`

	// Last cleanup timestamp
	LastCleanup *metav1.Time `json:"lastCleanup,omitempty"`

	// Next cleanup timestamp
	NextCleanup *metav1.Time `json:"nextCleanup,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Size",type="string",JSONPath=".spec.storage.size"
//+kubebuilder:printcolumn:name="Used",type="string",JSONPath=".status.storage.usedSize"
//+kubebuilder:printcolumn:name="Models",type="integer",JSONPath=".status.usage.totalModels"
//+kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// AIMCache is the Schema for the aimcaches API
type AIMCache struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AIMCacheSpec   `json:"spec,omitempty"`
	Status AIMCacheStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// AIMCacheList contains a list of AIMCache
type AIMCacheList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AIMCache `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AIMCache{}, &AIMCacheList{})
} 