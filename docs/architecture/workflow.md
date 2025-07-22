# AIM Engine - Complete Workflow Guide

## 🎯 **Overview**

This document describes the complete end-to-end workflow of AIM Engine, from user request to running inference endpoint. The workflow is designed to be intelligent, efficient, and user-friendly.

## 🔄 **Complete Workflow Diagram**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   USER REQUEST  │───▶│  INPUT VALIDATION│───▶│  AUTO-DETECTION │───▶│ RECIPE SELECTION│
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         ▼                       ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  aim-engine     │    │ Validate model  │    │ Detect GPUs     │    │ Load model-     │
│  launch         │    │ ID, GPU count,  │    │ Auto-select     │    │ specific        │
│  Qwen/Qwen3-32B │    │ precision,      │    │ optimal config  │    │ recipes only    │
│  --gpus 4       │    │ backend format  │    │ based on model  │    │ Find best       │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         ▼                       ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ CONFIGURATION   │───▶│  DOCKER SETUP   │───▶│ CONTAINER LAUNCH│───▶│ ENDPOINT READY  │
│ GENERATION      │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         ▼                       ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Generate Docker │    │ Pull vLLM       │    │ Launch container│    │ Health check    │
│ args, env vars, │    │ ROCm image      │    │ with GPU access │    │ Wait for ready  │
│ volume mounts   │    │ Setup networking│    │ Start vLLM      │    │ Test inference  │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 **Detailed Workflow Steps**

### **Phase 1: User Request & Input Processing**

#### **Step 1.1: User Command**
```bash
# User executes command
aim-engine launch Qwen/Qwen3-32B --gpus 4 --precision bf16 --backend vllm
```

#### **Step 1.2: Command Parsing**
```python
# aim_launcher.py main()
parser = argparse.ArgumentParser()
# Parse arguments
args = parser.parse_args()

# Initialize AIM Engine
launcher = AIMEngine()
```

#### **Step 1.3: Input Validation**
```python
def validate_inputs(self, model_id: str, gpu_count: Optional[int] = None, 
                   precision: Optional[str] = None, backend: str = 'vllm') -> bool:
    # Validate model_id format (org/model)
    # Validate GPU count range (1-8)
    # Validate precision (fp16, bf16, fp8, int8, int4)
    # Validate backend (vllm, sglang)
    return True/False
```

### **Phase 2: Auto-Detection & Resource Analysis**

#### **Step 2.1: GPU Detection**
```python
def _detect_available_gpus(self) -> int:
    try:
        # Run nvidia-smi --list-gpus
        result = subprocess.run(['nvidia-smi', '--list-gpus'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            gpu_count = len(result.stdout.strip().split('\n'))
            return gpu_count
    except Exception as e:
        # Fallback: assume 1 GPU
        return 1
```

#### **Step 2.2: Optimal Configuration Selection**
```python
def get_optimal_configuration(self, model_id: str, 
                            customer_gpu_count: Optional[int] = None,
                            customer_precision: Optional[str] = None,
                            backend: str = 'vllm') -> Optional[Dict]:
    
    # Step 1: Detect available GPUs
    available_gpus = self._detect_available_gpus()
    
    # Step 2: Determine optimal GPU count
    optimal_gpu_count = self._get_optimal_gpu_count(
        model_id, available_gpus, customer_gpu_count
    )
    
    # Step 3: Select optimal precision
    optimal_precision = self._select_best_precision(
        model_id, customer_precision
    )
    
    # Step 4: Find matching recipes
    matching_recipes = self.find_matching_recipes(
        model_id, optimal_gpu_count, optimal_precision, backend
    )
    
    # Step 5: Select best recipe
    selected_recipe = matching_recipes[0] if matching_recipes else None
    
    return {
        'recipe_id': selected_recipe['recipe_id'],
        'model_id': model_id,
        'gpu_count': optimal_gpu_count,
        'precision': optimal_precision,
        'backend': backend,
        'config': selected_recipe[f"{backend}_serve"][f"{optimal_gpu_count}_gpu"],
        'available_gpus': available_gpus
    }
```

### **Phase 3: Recipe Selection & Loading**

#### **Step 3.1: Model-Specific Recipe Loading**
```python
def _load_model_recipes(self, model_id: str) -> Dict[str, Dict]:
    model_recipes = {}
    
    # Only load recipes for this specific model
    for recipe_file in self.recipes_dir.glob("*.yaml"):
        with open(recipe_file, 'r') as f:
            recipe = yaml.safe_load(f)
            
            # Filter by model_id
            if recipe.get('huggingface_id') == model_id:
                model_recipes[recipe['recipe_id']] = recipe
    
    return model_recipes
```

#### **Step 3.2: Recipe Matching & Selection**
```python
def find_matching_recipes(self, model_id: str, gpu_count: int, 
                         precision: str, backend: str) -> List[Dict]:
    # Load recipes only for this model
    model_recipes = self._load_model_recipes(model_id)
    
    matching_recipes = []
    
    for recipe_id, recipe in model_recipes.items():
        # Check precision match
        if recipe.get('precision') != precision:
            continue
        
        # Check backend support
        backend_key = f"{backend}_serve"
        if backend_key not in recipe:
            continue
        
        # Check GPU count availability
        gpu_key = f"{gpu_count}_gpu"
        if gpu_key not in recipe[backend_key]:
            continue
        
        # Check enabled status
        if not recipe[backend_key][gpu_key].get('enabled', False):
            continue
        
        matching_recipes.append(recipe)
    
    return matching_recipes
```

### **Phase 4: Configuration Generation**

#### **Step 4.1: Docker Configuration Generation**
```python
def generate_config(self, recipe_config: Dict, gpu_count: int, 
                   precision: str, backend: str, port: int) -> Dict:
    
    # Generate Docker command arguments
    docker_args = self._generate_docker_args(recipe_config, port)
    
    # Generate environment variables
    env_vars = self._generate_env_vars(recipe_config, gpu_count, precision)
    
    # Generate volume mounts
    volume_mounts = self._generate_volume_mounts(recipe_config)
    
    return {
        'docker_args': docker_args,
        'env_vars': env_vars,
        'volume_mounts': volume_mounts,
        'image': 'rocm/vllm:latest',
        'gpu_count': gpu_count
    }
```

#### **Step 4.2: Example Generated Configuration**
```python
# Example configuration for Qwen/Qwen3-32B with 4 GPUs
config = {
    'docker_args': [
        '--model', 'Qwen/Qwen3-32B',
        '--dtype', 'bfloat16',
        '--tensor-parallel-size', '4',
        '--max-batch-size', '32',
        '--max-context-len', '32768',
        '--gpu-memory-utilization', '0.9',
        '--trust-remote-code', 'true',
        '--port', '8000'
    ],
    'env_vars': {
        'CUDA_VISIBLE_DEVICES': '0,1,2,3',
        'NCCL_DEBUG': 'INFO'
    },
    'volume_mounts': {
        '/workspace/models': '/workspace/models'
    },
    'image': 'rocm/vllm:latest',
    'gpu_count': 4
}
```

### **Phase 5: Docker Container Management**

#### **Step 5.1: Container Name Generation**
```python
def _generate_container_name(self, model_id: str, gpu_count: int, 
                           precision: str, backend: str) -> str:
    return f"aim-engine-{model_id.replace('/', '-').lower()}-{gpu_count}gpu-{precision}-{backend}"
```

#### **Step 5.2: Docker Container Launch**
```python
def launch_container(self, config: Dict, container_name: str, gpu_count: int) -> Dict:
    try:
        # Build Docker run command
        docker_cmd = [
            'docker', 'run',
            '--name', container_name,
            '--gpus', f'all:{gpu_count}',
            '--network', 'host',
            '--detach'
        ]
        
        # Add environment variables
        for key, value in config['env_vars'].items():
            docker_cmd.extend(['-e', f'{key}={value}'])
        
        # Add volume mounts
        for host_path, container_path in config['volume_mounts'].items():
            docker_cmd.extend(['-v', f'{host_path}:{container_path}'])
        
        # Add image and arguments
        docker_cmd.append(config['image'])
        docker_cmd.extend(config['docker_args'])
        
        # Execute Docker command
        result = subprocess.run(docker_cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            container_id = result.stdout.strip()
            return {
                "success": True,
                "container_id": container_id,
                "container_name": container_name
            }
        else:
            return {
                "success": False,
                "error": result.stderr
            }
            
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }
```

### **Phase 6: Endpoint Management & Health Checks**

#### **Step 6.1: Endpoint Readiness Check**
```python
def start_endpoint(self, container_id: str, config: Dict, port: int) -> Dict:
    endpoint_url = f"http://localhost:{port}"
    
    # Wait for container to be ready
    max_wait_time = 300  # 5 minutes
    check_interval = 5   # 5 seconds
    
    for attempt in range(max_wait_time // check_interval):
        # Check if container is running
        if not self._is_container_running(container_id):
            return {"success": False, "error": "Container stopped unexpectedly"}
        
        # Check endpoint health
        health_check = self.check_endpoint_health(endpoint_url)
        if health_check["success"]:
            return {"success": True, "endpoint_url": endpoint_url}
        
        time.sleep(check_interval)
    
    return {"success": False, "error": "Endpoint failed to become ready"}
```

#### **Step 6.2: Health Check Implementation**
```python
def check_endpoint_health(self, endpoint_url: str) -> Dict:
    try:
        response = requests.get(f"{endpoint_url}/health", timeout=10)
        if response.status_code == 200:
            return {"success": True, "status": "healthy"}
        else:
            return {"success": False, "status": f"HTTP {response.status_code}"}
    except Exception as e:
        return {"success": False, "status": str(e)}
```

#### **Step 6.3: Inference Test**
```python
def test_inference(self, endpoint_url: str, model_id: str, prompt: str) -> Dict:
    try:
        payload = {
            "model": model_id,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 100,
            "temperature": 0.7
        }
        
        start_time = time.time()
        response = requests.post(f"{endpoint_url}/v1/chat/completions", 
                               json=payload, timeout=30)
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "response_time": end_time - start_time,
                "tokens_generated": result["usage"]["completion_tokens"],
                "result": result
            }
        else:
            return {"success": False, "error": f"HTTP {response.status_code}"}
            
    except Exception as e:
        return {"success": False, "error": str(e)}
```

## 🔄 **Complete Workflow Example**

### **User Request**
```bash
aim-engine launch Qwen/Qwen3-32B --gpus 4 --precision bf16
```

### **Workflow Execution**

#### **Step 1: Input Processing**
```
INFO: Validating inputs...
INFO: Model ID: Qwen/Qwen3-32B ✓
INFO: GPU count: 4 ✓
INFO: Precision: bf16 ✓
INFO: Backend: vllm (default) ✓
```

#### **Step 2: Auto-Detection**
```
INFO: Detecting available GPUs...
INFO: Found 4 GPUs available
INFO: Customer specified GPU count: 4
INFO: Customer specified precision: bf16
INFO: Using vLLM backend
```

#### **Step 3: Recipe Selection**
```
INFO: Loading recipes for Qwen/Qwen3-32B...
INFO: Found 1 recipe: qwen3-32b-mi300x-bf16
INFO: Checking recipe compatibility...
INFO: ✓ Precision match: bf16
INFO: ✓ Backend support: vllm
INFO: ✓ GPU count available: 4_gpu
INFO: ✓ Configuration enabled: true
INFO: Selected recipe: qwen3-32b-mi300x-bf16
```

#### **Step 4: Configuration Generation**
```
INFO: Generating deployment configuration...
INFO: Docker image: rocm/vllm:latest
INFO: GPU access: --gpus all:4
INFO: Port mapping: 8000
INFO: Environment variables: CUDA_VISIBLE_DEVICES=0,1,2,3
INFO: Volume mounts: /workspace/models:/workspace/models
```

#### **Step 5: Container Launch**
```
INFO: Launching Docker container...
INFO: Container name: aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
INFO: Pulling rocm/vllm:latest (if needed)...
INFO: Starting container with GPU access...
INFO: Container ID: abc123def456
INFO: Container started successfully
```

#### **Step 6: Endpoint Readiness**
```
INFO: Waiting for endpoint to be ready...
INFO: Checking endpoint health...
INFO: Attempt 1/60: Container running, endpoint not ready
INFO: Attempt 2/60: Container running, endpoint not ready
INFO: Attempt 3/60: Container running, endpoint not ready
...
INFO: Attempt 12/60: Container running, endpoint ready! ✓
INFO: Endpoint URL: http://localhost:8000
```

#### **Step 7: Final Validation**
```
INFO: Testing inference endpoint...
INFO: Sending test prompt: "Hello, how are you?"
INFO: Response received in 2.34s
INFO: Generated 15 tokens
INFO: Inference test successful ✓
```

#### **Step 8: Success Response**
```json
{
  "success": true,
  "model_id": "Qwen/Qwen3-32B",
  "recipe_id": "qwen3-32b-mi300x-bf16",
  "container_id": "abc123def456",
  "container_name": "aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm",
  "endpoint_url": "http://localhost:8000",
  "gpu_count": 4,
  "available_gpus": 4,
  "precision": "bf16",
  "backend": "vllm",
  "port": 8000,
  "status": "running",
  "auto_selected": {
    "gpu_count": false,
    "precision": false
  }
}
```

## 🎯 **Workflow Key Features**

### **1. Intelligent Auto-Detection**
- **GPU Detection**: Automatically detects available GPUs
- **Optimal Selection**: Chooses best configuration based on model size
- **Smart Fallback**: Tries alternatives if primary choice fails

### **2. Efficient Resource Usage**
- **Model-Specific Loading**: Only loads recipes for the target model
- **Memory Optimization**: Minimal memory footprint
- **Fast Startup**: Quick recipe selection and configuration

### **3. Robust Error Handling**
- **Input Validation**: Comprehensive parameter validation
- **Graceful Degradation**: Falls back to available resources
- **Detailed Logging**: Clear feedback at each step

### **4. Production Ready**
- **Health Checks**: Ensures endpoint is fully functional
- **Inference Testing**: Validates model can serve requests
- **Resource Monitoring**: Tracks GPU usage and performance

## 🔧 **Workflow Customization**

### **Custom Recipe Selection**
```python
# Add custom selection logic
def custom_recipe_selector(self, model_id: str, requirements: Dict) -> Dict:
    # Custom logic for specific requirements
    # Performance optimization, cost considerations, etc.
    pass
```

### **Custom Health Checks**
```python
# Add custom health check endpoints
def custom_health_check(self, endpoint_url: str) -> Dict:
    # Custom health check logic
    # Load balancing, performance metrics, etc.
    pass
```

### **Custom Configuration Generation**
```python
# Add custom configuration templates
def generate_custom_config(self, recipe: Dict, requirements: Dict) -> Dict:
    # Custom configuration generation
    # Specialized hardware, custom optimizations, etc.
    pass
```

## 🎉 **Workflow Benefits**

### **For Users**
- ✅ **Simple**: Just specify the model, everything else is automatic
- ✅ **Fast**: Optimized for quick deployment
- ✅ **Reliable**: Comprehensive error handling and validation
- ✅ **Flexible**: Override any auto-selected option

### **For System Administrators**
- ✅ **Resource Efficient**: Uses available hardware optimally
- ✅ **Scalable**: Performance doesn't degrade with more models
- ✅ **Monitorable**: Detailed logging and health checks
- ✅ **Maintainable**: Clean, modular architecture

### **For Developers**
- ✅ **Extensible**: Easy to add new features and optimizations
- ✅ **Testable**: Each component can be tested independently
- ✅ **Documented**: Clear workflow and API documentation
- ✅ **Standards Compliant**: Follows best practices

The complete workflow ensures that AIM Engine provides a seamless, intelligent, and efficient experience for deploying AI model inference endpoints! 