# AIM Engine Detailed Technical Documentation

## **Overview**

AIM Engine is a comprehensive AI model deployment system that automatically optimizes configurations for AMD GPU hardware. It combines intelligent recipe selection, dynamic resource allocation, and performance monitoring to deliver optimal inference performance.

## **Architecture Components**

### **Core Components**

#### **1. Recipe Selector**
- **Purpose**: Intelligently selects optimal configurations based on model and hardware
- **Input**: Model ID, available GPUs, performance requirements
- **Output**: Optimized recipe configuration
- **Features**: GPU detection, model analysis, fallback strategies

#### **2. Configuration Generator**
- **Purpose**: Generates deployment configurations from recipes
- **Input**: Selected recipe, deployment target
- **Output**: Kubernetes manifests, Docker commands, environment variables
- **Features**: Multi-format output, validation, customization

#### **3. Model Cache Manager**
- **Purpose**: Manages model downloads and caching
- **Input**: Model ID, cache location
- **Output**: Cached model files, cache statistics
- **Features**: Incremental downloads, deduplication, cleanup

#### **4. Performance Monitor**
- **Purpose**: Tracks performance metrics and resource utilization
- **Input**: Runtime metrics, recipe targets
- **Output**: Performance reports, alerts, optimization suggestions
- **Features**: Real-time monitoring, historical analysis, alerting

### **Supporting Components**

#### **1. GPU Detection System**
```python
class GPUDetector:
    def detect_available_gpus(self):
        """Detect available AMD GPUs in the system"""
        # Implementation for AMD GPU detection
        pass
    
    def get_gpu_info(self):
        """Get detailed GPU information"""
        # Implementation for GPU info retrieval
        pass
```

#### **2. Recipe Database**
```python
class RecipeDatabase:
    def load_recipes(self, model_id):
        """Load recipes for a specific model"""
        # Implementation for recipe loading
        pass
    
    def find_matching_recipe(self, requirements):
        """Find recipe matching requirements"""
        # Implementation for recipe matching
        pass
```

#### **3. Configuration Validator**
```python
class ConfigurationValidator:
    def validate_recipe(self, recipe):
        """Validate recipe configuration"""
        # Implementation for recipe validation
        pass
    
    def validate_resources(self, recipe, available_resources):
        """Validate resource requirements"""
        # Implementation for resource validation
        pass
```

## **Recipe Selection Algorithm**

### **Algorithm Overview**

The recipe selection algorithm follows a multi-step process to determine the optimal configuration:

1. **Resource Detection**: Detect available hardware resources
2. **Model Analysis**: Analyze model requirements and characteristics
3. **Recipe Matching**: Find recipes matching requirements
4. **Performance Ranking**: Rank recipes by expected performance
5. **Resource Validation**: Validate against available resources
6. **Fallback Selection**: Select fallback if primary choice unavailable

### **Detailed Algorithm**

```python
def select_optimal_recipe(model_id, available_gpus, precision=None):
    """
    Select optimal recipe for given model and hardware
    
    Args:
        model_id: HuggingFace model ID
        available_gpus: Number of available GPUs
        precision: Preferred precision (optional)
    
    Returns:
        Optimal recipe configuration
    """
    
    # Step 1: Detect available resources
    gpu_info = detect_gpu_resources()
    memory_info = detect_memory_resources()
    cpu_info = detect_cpu_resources()
    
    # Step 2: Analyze model requirements
    model_requirements = analyze_model_requirements(model_id)
    optimal_gpu_count = calculate_optimal_gpu_count(model_requirements)
    optimal_precision = select_optimal_precision(model_requirements, gpu_info)
    
    # Step 3: Find matching recipes
    candidate_recipes = find_matching_recipes(
        model_id=model_id,
        gpu_count=min(optimal_gpu_count, available_gpus),
        precision=precision or optimal_precision
    )
    
    # Step 4: Rank recipes by performance
    ranked_recipes = rank_recipes_by_performance(candidate_recipes)
    
    # Step 5: Validate against resources
    valid_recipes = validate_recipe_resources(ranked_recipes, {
        'gpu': gpu_info,
        'memory': memory_info,
        'cpu': cpu_info
    })
    
    # Step 6: Select best recipe or fallback
    if valid_recipes:
        return valid_recipes[0]  # Best performing valid recipe
    else:
        return select_fallback_recipe(model_id, available_gpus)
```

### **GPU Count Selection**

```python
def calculate_optimal_gpu_count(model_requirements):
    """
    Calculate optimal GPU count based on model size
    """
    model_size = model_requirements['size']
    
    if model_size <= 8:  # 7B-8B models
        return 1
    elif model_size <= 14:  # 13B-14B models
        return 2
    elif model_size <= 34:  # 32B-34B models
        return 4
    elif model_size <= 72:  # 70B-72B models
        return 8
    else:  # Larger models
        return min(16, model_size // 8)  # Scale with model size
```

### **Precision Selection**

```python
def select_optimal_precision(model_requirements, gpu_info):
    """
    Select optimal precision based on model and hardware
    """
    model_size = model_requirements['size']
    gpu_memory = gpu_info['memory_per_gpu']
    
    # For large models or limited GPU memory, use bf16
    if model_size > 32 or gpu_memory < 24:
        return 'bf16'
    
    # For smaller models with sufficient memory, use fp16
    elif model_size <= 14 and gpu_memory >= 24:
        return 'fp16'
    
    # Default to bf16 for stability
    else:
        return 'bf16'
```

### **Fallback Strategy**

```python
def select_fallback_recipe(model_id, available_gpus):
    """
    Select fallback recipe when optimal recipe is not available
    """
    
    # Try different GPU counts
    for gpu_count in [available_gpus, available_gpus//2, 1]:
        if gpu_count > 0:
            recipe = find_recipe_with_gpu_count(model_id, gpu_count)
            if recipe:
                return recipe
    
    # Try different precisions
    for precision in ['bf16', 'fp16', 'fp8']:
        recipe = find_recipe_with_precision(model_id, precision)
        if recipe:
            return recipe
    
    # Return default recipe
    return get_default_recipe(model_id)
```

## **Model Caching System**

### **Cache Architecture**

The model caching system provides efficient storage and retrieval of downloaded models:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Model         │    │   Cache         │    │   Storage       │
│   Registry      │    │   Manager       │    │   System        │
│                 │    │                 │    │                 │
│ • Model         │───▶│ • Download      │───▶│ • Local Disk    │
│   Metadata      │    │   Management    │    │ • Network       │
│ • Version       │    │ • Cache         │    │   Storage       │
│   Information   │    │   Organization  │    │ • Cloud         │
│ • Download      │    │ • Cleanup       │    │   Storage       │
│   URLs          │    │ • Statistics    │    │ • Compression   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Cache Management**

```python
class ModelCacheManager:
    def __init__(self, cache_dir):
        self.cache_dir = cache_dir
        self.metadata_file = os.path.join(cache_dir, 'metadata.json')
    
    def download_model(self, model_id, force=False):
        """Download model to cache"""
        if not force and self.is_cached(model_id):
            return self.get_model_path(model_id)
        
        # Download model files
        model_path = self._download_model_files(model_id)
        
        # Update metadata
        self._update_metadata(model_id, model_path)
        
        return model_path
    
    def is_cached(self, model_id):
        """Check if model is cached"""
        metadata = self._load_metadata()
        return model_id in metadata
    
    def get_model_path(self, model_id):
        """Get cached model path"""
        metadata = self._load_metadata()
        return metadata.get(model_id, {}).get('path')
    
    def cleanup_old_models(self, max_age_days=30):
        """Clean up old cached models"""
        metadata = self._load_metadata()
        current_time = time.time()
        
        for model_id, info in metadata.items():
            if current_time - info['timestamp'] > max_age_days * 86400:
                self._remove_model(model_id)
    
    def get_cache_stats(self):
        """Get cache statistics"""
        metadata = self._load_metadata()
        total_size = sum(info['size'] for info in metadata.values())
        
        return {
            'total_models': len(metadata),
            'total_size_gb': total_size / (1024**3),
            'cache_dir': self.cache_dir
        }
```

### **Cache Optimization**

#### **Deduplication**
- **Shared Components**: Common model components are shared between models
- **Incremental Downloads**: Only download new or changed files
- **Compression**: Compress model files to save storage space

#### **Performance Optimization**
- **Memory Mapping**: Use memory mapping for large model files
- **Parallel Downloads**: Download model files in parallel
- **Background Prefetching**: Prefetch models likely to be used

#### **Storage Management**
- **Automatic Cleanup**: Remove old unused models
- **Size Limits**: Enforce cache size limits
- **Priority Management**: Keep frequently used models

## **Key Performance Indicators (KPIs)**

### **Throughput Metrics**

#### **Tokens per Second**
- **Definition**: Number of tokens generated per second
- **Measurement**: Average over time window
- **Targets**: Vary by model size and GPU count
- **Monitoring**: Real-time tracking and alerting

#### **Requests per Second**
- **Definition**: Number of API requests processed per second
- **Measurement**: Rate of incoming requests
- **Targets**: Based on hardware capacity
- **Monitoring**: Load balancing and scaling decisions

### **Latency Metrics**

#### **First Token Latency**
- **Definition**: Time from request to first token generation
- **Measurement**: End-to-end timing
- **Targets**: < 100ms for most models
- **Monitoring**: User experience indicator

#### **End-to-End Latency**
- **Definition**: Total time to complete request
- **Measurement**: Request start to response end
- **Targets**: Based on model size and complexity
- **Monitoring**: Overall performance indicator

### **Resource Utilization**

#### **GPU Utilization**
- **Definition**: Percentage of GPU compute capacity used
- **Measurement**: Average over time window
- **Targets**: 80-90% for optimal performance
- **Monitoring**: Performance optimization

#### **Memory Utilization**
- **Definition**: Percentage of GPU memory used
- **Measurement**: Peak and average usage
- **Targets**: < 95% to avoid OOM errors
- **Monitoring**: Resource management

### **Quality Metrics**

#### **Model Accuracy**
- **Definition**: Quality of generated outputs
- **Measurement**: Automated and manual evaluation
- **Targets**: Model-specific benchmarks
- **Monitoring**: Quality assurance

#### **Response Quality**
- **Definition**: Relevance and coherence of responses
- **Measurement**: User feedback and automated metrics
- **Targets**: Application-specific requirements
- **Monitoring**: User satisfaction

## **Configuration Generation**

### **vLLM Configuration**

```python
def generate_vllm_config(recipe):
    """Generate vLLM configuration from recipe"""
    
    config = {
        'model': recipe['huggingface_id'],
        'dtype': recipe['precision'],
        'tensor_parallel_size': recipe['gpu_count'],
        'max_model_len': recipe['config']['args']['max_model_len'],
        'max_num_batched_tokens': recipe['config']['args']['max_num_batched_tokens'],
        'gpu_memory_utilization': recipe['config']['args']['gpu_memory_utilization'],
        'trust_remote_code': recipe['config']['args'].get('trust_remote_code', True),
        'host': '0.0.0.0',
        'port': 8000
    }
    
    return config
```

### **Docker Configuration**

```python
def generate_docker_config(recipe):
    """Generate Docker configuration from recipe"""
    
    config = {
        'image': 'rocm/vllm:latest',
        'ports': ['8000:8000'],
        'devices': ['/dev/kfd', '/dev/dri'],
        'group_add': ['video', 'render'],
        'volumes': ['/workspace/model-cache:/workspace/model-cache'],
        'environment': recipe['config']['env_vars'],
        'command': ['python3', '-m', 'vllm.entrypoints.openai.api_server'],
        'args': recipe_to_vllm_args(recipe)
    }
    
    return config
```

### **Kubernetes Configuration**

```python
def generate_kubernetes_config(recipe):
    """Generate Kubernetes configuration from recipe"""
    
    deployment = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': 'aim-engine'},
        'spec': {
            'replicas': 1,
            'selector': {'matchLabels': {'app': 'aim-engine'}},
            'template': {
                'metadata': {'labels': {'app': 'aim-engine'}},
                'spec': {
                    'containers': [{
                        'name': 'aim-engine',
                        'image': 'rocm/vllm:latest',
                        'resources': {
                            'requests': {
                                'amd.com/gpu': str(recipe['gpu_count']),
                                'memory': recipe['resources']['requests']['memory'],
                                'cpu': recipe['resources']['requests']['cpu']
                            },
                            'limits': {
                                'amd.com/gpu': str(recipe['gpu_count']),
                                'memory': recipe['resources']['limits']['memory'],
                                'cpu': recipe['resources']['limits']['cpu']
                            }
                        },
                        'command': ['python3', '-m', 'vllm.entrypoints.openai.api_server'],
                        'args': recipe_to_vllm_args(recipe),
                        'env': recipe_to_env_vars(recipe)
                    }]
                }
            }
        }
    }
    
    return deployment
```

## **Optimization Strategies**

### **Performance Optimization**

#### **GPU Optimization**
- **Memory Management**: Optimize GPU memory allocation
- **Kernel Selection**: Choose optimal CUDA kernels
- **Parallelization**: Maximize GPU utilization
- **Precision Tuning**: Balance accuracy and speed

#### **Model Optimization**
- **Quantization**: Reduce model precision for speed
- **Pruning**: Remove unnecessary model weights
- **Distillation**: Create smaller, faster models
- **Caching**: Cache intermediate computations

#### **System Optimization**
- **I/O Optimization**: Minimize disk and network I/O
- **Memory Management**: Optimize system memory usage
- **Process Management**: Efficient process scheduling
- **Network Optimization**: Minimize network latency

### **Resource Optimization**

#### **GPU Resource Management**
- **Memory Allocation**: Efficient GPU memory allocation
- **Load Balancing**: Distribute load across GPUs
- **Power Management**: Optimize GPU power consumption
- **Thermal Management**: Monitor and manage GPU temperature

#### **System Resource Management**
- **CPU Allocation**: Optimize CPU usage
- **Memory Allocation**: Efficient memory management
- **Storage Optimization**: Optimize storage usage
- **Network Management**: Optimize network usage

### **Cost Optimization**

#### **Hardware Optimization**
- **Right-sizing**: Choose appropriate hardware
- **Scaling**: Scale based on demand
- **Consolidation**: Consolidate workloads
- **Efficiency**: Maximize resource utilization

#### **Operational Optimization**
- **Automation**: Automate deployment and management
- **Monitoring**: Proactive monitoring and alerting
- **Maintenance**: Regular maintenance and updates
- **Documentation**: Comprehensive documentation

## **Workflow Summary**

### **Deployment Workflow**

1. **Model Selection**: Choose model to deploy
2. **Hardware Detection**: Detect available hardware
3. **Recipe Selection**: Select optimal recipe
4. **Configuration Generation**: Generate deployment config
5. **Validation**: Validate configuration
6. **Deployment**: Deploy to target environment
7. **Monitoring**: Monitor performance and health
8. **Optimization**: Optimize based on metrics

### **Maintenance Workflow**

1. **Monitoring**: Monitor system health and performance
2. **Alerting**: Respond to alerts and issues
3. **Updates**: Apply updates and patches
4. **Optimization**: Optimize based on performance data
5. **Scaling**: Scale based on demand
6. **Backup**: Regular backups and recovery testing

### **Development Workflow**

1. **Development**: Develop new features and improvements
2. **Testing**: Test changes thoroughly
3. **Validation**: Validate against requirements
4. **Deployment**: Deploy to development environment
5. **Integration**: Integrate with existing systems
6. **Documentation**: Update documentation
7. **Release**: Release to production

This detailed technical documentation provides a comprehensive understanding of the AIM Engine system architecture, components, and workflows. 
