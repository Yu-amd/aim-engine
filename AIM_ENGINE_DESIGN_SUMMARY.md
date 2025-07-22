# AIM Engine Design Summary

## 🎯 **Overview**

AIM (AMD Inference Microservice) Engine is an intelligent AI model deployment system that automatically selects optimal configurations for serving large language models on AMD hardware. It combines recipe-based optimization with dynamic resource detection to deliver the best performance for any given model and hardware setup.

## 🏗️ **Architecture Components**

### **1. Core Classes**

#### **`AIMRecipeSelector`** (`aim_recipe_selector.py`)
- **Purpose**: Intelligent recipe selection and resource optimization
- **Key Responsibilities**:
  - GPU detection and validation
  - Model-specific configuration optimization
  - Recipe matching and fallback strategies
  - Precision and GPU count selection

#### **`AIMConfigGenerator`** (`aim_config_generator.py`)
- **Purpose**: Generates deployment configurations from selected recipes
- **Key Responsibilities**:
  - vLLM command generation
  - Environment variable setup
  - Docker configuration creation
  - Container resource allocation

#### **`AIMCacheManager`** (`aim_cache_manager.py`)
- **Purpose**: Intelligent model caching and storage management
- **Key Responsibilities**:
  - Model download caching and storage
  - Cache index management and metadata tracking
  - Cache statistics and cleanup operations
  - Environment variable generation for cached models
  - Volume mount configuration for Docker deployments

### **2. Data Structure**

#### **Models Directory** (`models/`)
- **Purpose**: Model metadata and characteristics
- **Format**: YAML files with model information
- **Key Fields**:
  - `model_id`: Hugging Face model identifier
  - `size`: Model size (7B, 13B, 32B, 70B, etc.)
  - `family`: Model family (Qwen, Llama, etc.)
  - `readiness_level`: Production readiness status
  - `aim_recipes`: Available recipe configurations

#### **Cache Directory** (`/workspace/model-cache/`)
- **Purpose**: Persistent model storage and caching
- **Structure**:
  ```
  /workspace/model-cache/
  ├── cache_index.json          # Cache metadata and statistics
  ├── models/                   # Cached model files
  │   ├── Qwen--Qwen3-32B/     # Model-specific cache
  │   ├── meta-llama--Llama-2-7b-chat-hf/
  │   └── ...
  ├── tokenizers/              # Cached tokenizer files
  ├── configs/                 # Cached model configurations
  └── datasets/                # Cached dataset files
  ```
- **Key Features**:
  - **Persistent Storage**: Survives container restarts
  - **Shared Access**: Multiple containers can use same cache
  - **Metadata Tracking**: Cache index with timestamps and sizes
  - **Automatic Cleanup**: Configurable retention policies

#### **Recipes Directory** (`recipes/`)
- **Purpose**: Performance-tuned configurations for specific models
- **Format**: YAML files with hardware-specific optimizations
- **Key Structure**:
  ```yaml
  recipe_id: qwen3-32b-mi300x-bf16
  model_id: Qwen/Qwen3-32B
  hardware: MI300X
  precision: bf16
  vllm_serve:
    1_gpu:
      enabled: true
      args:
        --model: Qwen/Qwen3-32B
        --dtype: bfloat16
        --max-num-batched-tokens: '8192'
        --max-model-len: '32768'
        --gpu-memory-utilization: '0.9'
    2_gpu:
      enabled: true
      args:
        --tensor-parallel-size: '2'
        --max-num-batched-tokens: '16384'
        # ... more optimized parameters
  ```

## 🔍 **Recipe Selection Algorithm**

### **Phase 1: Resource Detection**

#### **Multi-Level GPU Detection**
```python
def get_optimal_configuration(self, model_id, customer_gpu_count=None, 
                            customer_precision=None, backend='vllm'):
    # 1. Detect GPUs at multiple levels
    vllm_gpus = self._detect_vllm_gpus()        # What vLLM can actually use
    container_gpus = self._detect_container_gpus()  # Container-level detection
    host_gpus = self._detect_available_gpus()   # Host-level detection
    
    # 2. Use vLLM GPU count for actual configuration
    actual_gpu_count = self._get_optimal_gpu_count(model_id, vllm_gpus, customer_gpu_count)
    actual_precision = self._select_best_precision(model_id, customer_precision)
```

#### **GPU Detection Methods**
1. **AMD ROCm Detection** (`rocm-smi`):
   - Primary method for AMD GPUs
   - Uses `--showproductname` and `--list-gpus`
   - Counts GPU entries in output

2. **PyTorch Detection**:
   - Fallback method using `torch.cuda.device_count()`
   - Works with ROCm backend (CUDA compatibility layer)

3. **Environment Variables**:
   - `HIP_VISIBLE_DEVICES` (AMD/ROCm)

### **Phase 2: Optimal Configuration Selection**

#### **GPU Count Selection Logic**
```python
def _get_optimal_gpu_count(self, model_id, available_gpus, customer_gpu_count=None):
    # Customer preference takes priority
    if customer_gpu_count is not None:
        return min(customer_gpu_count, available_gpus)
    
    # Auto-selection based on model size
    model_size = self.models.get(model_id, {}).get('size', 'unknown')
    
    if model_size in ['7B', '8B'] and available_gpus >= 1:
        return 1
    elif model_size in ['13B', '14B'] and available_gpus >= 2:
        return 2
    elif model_size in ['32B', '34B'] and available_gpus >= 4:
        return 4
    elif model_size in ['70B', '72B'] and available_gpus >= 8:
        return 8
    else:
        return available_gpus  # Use maximum available
```

#### **Precision Selection Logic**
```python
def _select_best_precision(self, model_id, customer_precision=None):
    if customer_precision:
        return customer_precision
    
    model_size = self.models.get(model_id, {}).get('size', 'unknown')
    
    if model_size in ['7B', '8B']:
        return 'fp16'  # Smaller models can use fp16
    elif model_size in ['13B', '14B']:
        return 'bf16'  # Medium models benefit from bf16
    else:
        return 'bf16'  # Larger models use bf16 for stability
```

### **Phase 3: Recipe Matching & Fallback**

#### **Primary Recipe Selection**
```python
# Try optimal configuration first
recipe = self.select_best_recipe(model_id, actual_gpu_count, actual_precision, backend)

# If no match, try alternative configurations
if not recipe:
    # 1. Try different GPU counts (prefer higher counts)
    for gpu_count in [8, 4, 2, 1]:
        if gpu_count <= vllm_gpus:
            recipe = self.select_best_recipe(model_id, gpu_count, actual_precision, backend)
            if recipe:
                break
    
    # 2. Try different precisions
    if not recipe:
        for precision in ['bf16', 'fp16', 'fp8']:
            for gpu_count in [8, 4, 2, 1]:
                if gpu_count <= vllm_gpus:
                    recipe = self.select_best_recipe(model_id, gpu_count, precision, backend)
                    if recipe:
                        break
```

#### **Recipe Matching Criteria**
1. **Model ID Match**: Recipe must match the target model
2. **GPU Count Match**: Recipe must support the requested GPU count
3. **Precision Match**: Recipe must support the requested precision
4. **Backend Match**: Recipe must support the requested backend (vLLM, sglang)
5. **Enabled Status**: Recipe configuration must be enabled

## 🗄️ **Model Caching System**

### **Cache Architecture**

#### **Cache Manager Components**
```python
class AIMCacheManager:
    def __init__(self, cache_dir: str = "/workspace/model-cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_index_file = self.cache_dir / "cache_index.json"
        self.cache_index = self._load_cache_index()
```

#### **Cache Index Structure**
```json
{
  "Qwen/Qwen3-32B": {
    "cached": true,
    "cache_path": "/workspace/model-cache/models/Qwen--Qwen3-32B",
    "commit_hash": "abc123def456",
    "cached_at": "2024-01-15T10:30:00",
    "size": 64424509440
  }
}
```

### **Caching Workflow**

#### **1. Cache Detection**
```python
def is_model_cached(self, model_id: str) -> bool:
    cache_info = self.get_cache_info(model_id)
    if not cache_info:
        return False
    
    # Check if model files exist
    model_path = self.cache_dir / "models" / model_id.replace("/", "--")
    return model_path.exists() and cache_info.get("cached", False)
```

#### **2. Cache Addition**
```python
def add_model_to_cache(self, model_id: str, model_path: Path, commit_hash: str = None):
    # Create cache directory for model
    cache_path = self.get_model_cache_path(model_id)
    cache_path.mkdir(parents=True, exist_ok=True)
    
    # Copy model files to cache
    shutil.copytree(model_path, cache_path, dirs_exist_ok=True)
    
    # Update cache index with metadata
    self.cache_index[model_id] = {
        "cached": True,
        "cache_path": str(cache_path),
        "commit_hash": commit_hash,
        "cached_at": datetime.now().isoformat(),
        "size": self._get_directory_size(cache_path)
    }
```

#### **3. Cache Environment Setup**
```python
def generate_cache_environment(self, model_id: str) -> Dict[str, str]:
    env_vars = {
        "HF_HOME": str(self.cache_dir),
        "TRANSFORMERS_CACHE": str(self.cache_dir),
        "HF_DATASETS_CACHE": str(self.cache_dir),
        "VLLM_CACHE_DIR": str(self.cache_dir),
        "HF_HUB_DISABLE_TELEMETRY": "1"
    }
    
    # If model is cached, add specific path
    if self.is_model_cached(model_id):
        cache_path = self.get_model_cache_path(model_id)
        env_vars["MODEL_CACHE_PATH"] = str(cache_path)
    
    return env_vars
```

#### **4. Cache Volume Mounting**
```python
def generate_cache_volumes(self, model_id: str) -> List[str]:
    volumes = [f"{self.cache_dir}:/workspace/model-cache:ro"]
    
    # If model is cached, add specific model volume
    if self.is_model_cached(model_id):
        cache_path = self.get_model_cache_path(model_id)
        volumes.append(f"{cache_path}:/workspace/models/{model_id.replace('/', '--')}:ro")
    
    return volumes
```

### **Cache Management Operations**

#### **Cache Statistics**
```python
def get_cache_stats(self) -> Dict:
    cached_models = self.list_cached_models()
    total_size = sum(model["size"] for model in cached_models)
    
    return {
        "total_models": len(cached_models),
        "total_size": total_size,
        "total_size_gb": total_size / (1024**3),
        "cache_dir": str(self.cache_dir),
        "models": cached_models
    }
```

#### **Cache Cleanup**
```python
def cleanup_old_models(self, days_old: int = 30):
    cutoff_date = datetime.now().timestamp() - (days_old * 24 * 60 * 60)
    models_to_remove = []
    
    for model_id, info in self.cache_index.items():
        if info.get("cached", False):
            cached_at = datetime.fromisoformat(info["cached_at"]).timestamp()
            if cached_at < cutoff_date:
                models_to_remove.append(model_id)
    
    for model_id in models_to_remove:
        self.remove_model_from_cache(model_id)
```

### **Cache Performance Benefits**

#### **1. Deployment Speed**
- **First Deployment**: Downloads and caches model (slower)
- **Subsequent Deployments**: Uses cached model (instant)
- **Speed Improvement**: 10-100x faster for cached models

#### **2. Network Efficiency**
- **Bandwidth Savings**: No repeated downloads
- **Offline Capability**: Works without internet after caching
- **Reduced Latency**: Local model access

#### **3. Resource Optimization**
- **Storage Efficiency**: Shared cache across containers
- **Memory Optimization**: Pre-loaded model components
- **Disk I/O Reduction**: Local cache access vs network downloads

#### **4. Reliability**
- **Consistent Availability**: Models always available locally
- **Version Control**: Commit hash tracking for model versions
- **Fallback Support**: Graceful handling of cache misses

### **Cache Integration with Recipe Selection**

#### **Cache-Aware Deployment**
```python
# In generate_docker_command.py
docker_command = f"""docker run --rm \\
  --name {container_name} \\
  --device=/dev/kfd \\
  --device=/dev/dri \\
  --group-add=video \\
  --group-add=render \\
  -v /workspace/model-cache:/workspace/model-cache \\  # Cache volume mount
  -p {port}:8000 \\
  rocm/vllm:latest \\
  {vllm_command}"""
```

#### **Cache Status in Recipe Selection**
- **Cache Hit**: Use cached model, skip download
- **Cache Miss**: Download and cache model for future use
- **Cache Validation**: Verify model integrity and version

## 📊 **Key Performance Indicators (KPIs)**

### **1. Resource Utilization KPIs**
- **GPU Memory Utilization**: Target 90% (`--gpu-memory-utilization: '0.9'`)
- **GPU Count Optimization**: Match model size to optimal GPU count
- **Memory Efficiency**: Use appropriate precision for model size

### **2. Throughput KPIs**
- **Batch Token Capacity**: Scales with GPU count
  - 1 GPU: 8,192 tokens
  - 2 GPU: 16,384 tokens
  - 4 GPU: 32,768 tokens
  - 8 GPU: 65,536 tokens
- **Model Length**: Consistent 32,768 tokens across configurations
- **Tensor Parallelism**: Automatic scaling with GPU count

### **3. Latency KPIs**
- **Model Loading Time**: Optimized through caching
- **First Token Latency**: Minimized through precision selection
- **Inference Speed**: Optimized through hardware-specific recipes

### **4. Reliability KPIs**
- **Fallback Success Rate**: Multiple fallback strategies
- **Resource Validation**: GPU availability verification
- **Configuration Validation**: Recipe parameter validation

### **5. Caching KPIs**
- **Cache Hit Rate**: Percentage of deployments using cached models
- **Cache Efficiency**: Storage utilization and cleanup effectiveness
- **Deployment Speed**: Time reduction from first to subsequent deployments
- **Cache Persistence**: Cache survival rate across container restarts

## 🔧 **Configuration Generation**

### **vLLM Command Generation**
```python
def _build_command(self, recipe_config, backend, port):
    args = recipe_config.get('args', {})
    
    # Build command string
    command_parts = [f"python -m vllm.entrypoints.openai.api_server"]
    
    for arg, value in args.items():
        if arg == '--port':
            command_parts.append(f"{arg} {port}")
        else:
            command_parts.append(f"{arg} {value}")
    
    return " ".join(command_parts)
```

### **Environment Variable Setup**
```python
def _build_environment(self, recipe, precision, backend):
    env = {
        'HIP_VISIBLE_DEVICES': '0,1,2,3,4,5,6,7',  # AMD/ROCm primary
        'PYTORCH_ROCM_ARCH': 'gfx90a',  # MI300X architecture
        'VLLM_USE_ROCM': '1'  # Enable ROCm backend
    }
    return env
```

## 🎯 **Optimization Strategies**

### **1. Model-Size Based Optimization**
- **Small Models (7B-8B)**: Single GPU, fp16 precision
- **Medium Models (13B-14B)**: 2 GPUs, bf16 precision
- **Large Models (32B-34B)**: 4+ GPUs, bf16 precision
- **XL Models (70B+)**: 8 GPUs, bf16 precision

### **2. Hardware-Specific Optimization**
- **MI300X**: Optimized for high memory bandwidth
- **MI325X**: Optimized for next-generation performance
- **Precision Selection**: Hardware-aware precision choices

### **3. Dynamic Resource Allocation**
- **GPU Count Scaling**: Automatic tensor parallelism
- **Memory Utilization**: Optimized memory usage (90%)
- **Batch Size Scaling**: Token capacity scales with GPU count

### **4. Fallback Mechanisms**
- **GPU Count Fallback**: Try lower GPU counts if optimal not available
- **Precision Fallback**: Try alternative precisions
- **Backend Fallback**: Support multiple backends (vLLM, sglang)

## 📈 **Performance Benefits**

### **1. Automated Optimization**
- **Zero Configuration**: Works out-of-the-box
- **Hardware Awareness**: Automatically detects and optimizes for AMD GPUs
- **Model Intelligence**: Understands model characteristics and requirements

### **2. Resource Efficiency**
- **Optimal GPU Allocation**: Matches model size to GPU count
- **Memory Optimization**: Uses appropriate precision for model size
- **Throughput Scaling**: Batch capacity scales with available resources

### **3. Reliability**
- **Multiple Fallbacks**: Robust error handling and fallback strategies
- **Resource Validation**: Verifies GPU availability before deployment
- **Configuration Validation**: Ensures recipe parameters are valid

### **4. Maintainability**
- **Recipe-Based**: Easy to add new models and configurations
- **Hardware Agnostic**: Supports different AMD GPU generations
- **Backend Flexible**: Supports multiple inference backends

## 🔄 **Workflow Summary**

1. **Input**: Model ID + optional GPU count/precision
2. **Cache Check**: Verify if model is already cached locally
3. **Detection**: Multi-level GPU detection (vLLM → Container → Host)
4. **Optimization**: Model-size based GPU count and precision selection
5. **Matching**: Find best recipe matching requirements
6. **Fallback**: Try alternative configurations if primary fails
7. **Cache Integration**: Add cache volume mounts and environment variables
8. **Generation**: Create optimized vLLM command and environment
9. **Output**: Ready-to-run Docker command with optimal parameters and cache access

This design ensures that AIM Engine automatically delivers the best possible performance for any model on any AMD hardware configuration, with robust fallback mechanisms and comprehensive resource optimization. 
