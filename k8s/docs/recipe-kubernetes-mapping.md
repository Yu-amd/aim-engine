# AIM Engine Recipe Selection & Kubernetes Implications

This document provides a comprehensive analysis of how AIM Engine's recipe selection system maps to Kubernetes deployment configurations and the implications for production deployments.

## **Recipe Selection Algorithm**

### **Core Algorithm**
1. **GPU Detection**: Detect available AMD GPUs in the cluster
2. **Model Analysis**: Determine optimal GPU count based on model size
3. **Precision Selection**: Choose optimal precision (bf16, fp16, fp8)
4. **Recipe Matching**: Find recipes matching requirements
5. **Fallback Strategy**: Try alternative configurations if needed
6. **Validation**: Validate selected recipe against cluster resources

### **GPU Count Selection**
```python
def select_gpu_count(model_size: str, available_gpus: int) -> int:
    # Model size heuristics
    if "7b" in model_size.lower() or "8b" in model_size.lower():
        return min(1, available_gpus)
    elif "13b" in model_size.lower() or "14b" in model_size.lower():
        return min(2, available_gpus)
    elif "32b" in model_size.lower() or "34b" in model_size.lower():
        return min(4, available_gpus)
    elif "70b" in model_size.lower() or "72b" in model_size.lower():
        return min(8, available_gpus)
    else:
        return min(available_gpus, 1)  # Default to 1 GPU
```

### **Precision Selection**
```python
def select_precision(model_size: str, gpu_count: int) -> str:
    # Precision heuristics
    if gpu_count >= 4:
        return "bf16"  # Better numerical stability for large models
    elif "7b" in model_size.lower() or "8b" in model_size.lower():
        return "fp16"  # Faster for smaller models
    else:
        return "bf16"  # Default to bf16
```

## **Recipe Structure Analysis**

### **Recipe Components**
```yaml
recipe_id: qwen3-32b-4gpu-bf16
huggingface_id: Qwen/Qwen3-32B
hardware: MI300X
gpu_count: 4
precision: bf16
backend: vllm
config:
  args:
    max_model_len: 32768
    max_num_batched_tokens: 8192
    gpu_memory_utilization: 0.9
    tensor_parallel_size: 4
    trust_remote_code: true
  env_vars:
    VLLM_USE_ROCM: "1"
    PYTORCH_ROCM_ARCH: "gfx90a"
    HIP_VISIBLE_DEVICES: "0,1,2,3"
performance:
  expected_tokens_per_second: 5000
  expected_latency_ms: 100
  expected_throughput: 100
resources:
  requests:
    amd.com/gpu: "4"
    memory: "64Gi"
    cpu: "16"
  limits:
    amd.com/gpu: "4"
    memory: "128Gi"
    cpu: "32"
```

### **Resource Mapping**
| Recipe Field | Kubernetes Resource | Mapping Logic |
|--------------|-------------------|---------------|
| `gpu_count` | `amd.com/gpu` | Direct mapping |
| `resources.memory` | `memory` | Direct mapping |
| `resources.cpu` | `cpu` | Direct mapping |
| `config.args` | `command.args` | Argument generation |
| `config.env_vars` | `env` | Environment variables |
| `performance` | `annotations` | Performance metadata |

## **Kubernetes Deployment Implications**

### **Dynamic Resource Allocation**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aim-engine
spec:
  template:
    spec:
      containers:
      - name: aim-engine
        resources:
          requests:
            amd.com/gpu: "4"  # From recipe gpu_count
            memory: "64Gi"    # From recipe resources.requests.memory
            cpu: "16"         # From recipe resources.requests.cpu
          limits:
            amd.com/gpu: "4"  # From recipe gpu_count
            memory: "128Gi"   # From recipe resources.limits.memory
            cpu: "32"         # From recipe resources.limits.cpu
```

### **Command Generation**
```yaml
# Recipe config.args
config:
  args:
    max_model_len: 32768
    max_num_batched_tokens: 8192
    gpu_memory_utilization: 0.9

# Generated Kubernetes command
command: ["python3", "-m", "vllm.entrypoints.openai.api_server"]
args:
  - "--model"
  - "Qwen/Qwen3-32B"
  - "--dtype"
  - "bfloat16"
  - "--max-model-len"
  - "32768"
  - "--max-num-batched-tokens"
  - "8192"
  - "--gpu-memory-utilization"
  - "0.9"
  - "--tensor-parallel-size"
  - "4"
```

### **Environment Variable Mapping**
```yaml
# Recipe config.env_vars
config:
  env_vars:
    VLLM_USE_ROCM: "1"
    PYTORCH_ROCM_ARCH: "gfx90a"
    HIP_VISIBLE_DEVICES: "0,1,2,3"

# Kubernetes environment variables
env:
  - name: VLLM_USE_ROCM
    value: "1"
  - name: PYTORCH_ROCM_ARCH
    value: "gfx90a"
  - name: HIP_VISIBLE_DEVICES
    value: "0,1,2,3"
```

## **Recipe-to-Kubernetes Mapping**

### **Resource Quotas**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: aim-engine-quota
spec:
  hard:
    amd.com/gpu: "8"  # Based on max recipe GPU count
    memory: "128Gi"   # Based on max recipe memory
    cpu: "32"         # Based on max recipe CPU
```

### **Node Affinity**
```yaml
# Recipe-based node selection
nodeSelector:
  amd.com/gpu: "true"
  hardware: "MI300X"  # From recipe hardware field
```

### **Horizontal Pod Autoscaler**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: aim-engine-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: aim-engine
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: amd.com/gpu
      target:
        type: Utilization
        averageUtilization: 80
```

### **Persistent Volume Claims**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aim-engine-cache
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi  # Based on model cache requirements
```

## **Helm Chart Recipe Integration**

### **Values.yaml Structure**
```yaml
aim_engine:
  recipe:
    auto_select: true
    model_id: "Qwen/Qwen3-32B"
    fallback_enabled: true
    constraints:
      max_gpu_count: 8
      min_gpu_count: 1
      preferred_precision: "bf16"
  
  # Manual overrides
  overrides:
    gpu_count: null  # Override auto-detected GPU count
    precision: null  # Override auto-selected precision
    backend: null    # Override auto-selected backend
    vllm_args: {}    # Additional vLLM arguments
    env_vars: {}     # Additional environment variables
  
  # Performance tuning
  performance:
    max_batch_size: 32
    max_input_length: 4096
    max_output_length: 2048
  
  # Hardware configuration
  hardware:
    gpu_type: "MI300X"
    memory_utilization: 0.9
    cpu_cores: 16
```

### **Template Logic**
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "aim-engine.fullname" . }}
spec:
  template:
    spec:
      containers:
      - name: aim-engine
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        resources:
          requests:
            amd.com/gpu: {{ .Values.aim_engine.recipe.gpu_count | quote }}
            memory: {{ .Values.aim_engine.recipe.memory | quote }}
            cpu: {{ .Values.aim_engine.recipe.cpu | quote }}
          limits:
            amd.com/gpu: {{ .Values.aim_engine.recipe.gpu_count | quote }}
            memory: {{ .Values.aim_engine.recipe.memory_limit | quote }}
            cpu: {{ .Values.aim_engine.recipe.cpu_limit | quote }}
        command: {{ .Values.aim_engine.recipe.command }}
        args: {{ .Values.aim_engine.recipe.args }}
        env: {{ .Values.aim_engine.recipe.env_vars }}
```

### **Recipe Selection Hook**
```yaml
# templates/recipe-selector-hook.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "aim-engine.fullname" . }}-recipe-selector
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
spec:
  template:
    spec:
      containers:
      - name: recipe-selector
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        command: ["python3", "-m", "aim_engine.recipe_selector"]
        args:
          - "--model-id", {{ .Values.aim_engine.recipe.model_id | quote }}
          - "--auto-select", {{ .Values.aim_engine.recipe.auto_select | quote }}
          - "--fallback-enabled", {{ .Values.aim_engine.recipe.fallback_enabled | quote }}
        env:
          - name: MODEL_ID
            value: {{ .Values.aim_engine.recipe.model_id | quote }}
          - name: GPU_COUNT
            value: {{ .Values.aim_engine.recipe.gpu_count | quote }}
          - name: PRECISION
            value: {{ .Values.aim_engine.recipe.precision | quote }}
      restartPolicy: Never
```

## **Implementation Strategies**

### **Strategy 1: Recipe-First Deployment**
```bash
# 1. Select optimal recipe
aim-engine select-recipe Qwen/Qwen3-32B --gpu-count 4

# 2. Generate Kubernetes config
aim-engine generate-k8s-config qwen3-32b-mi300x-bf16

# 3. Deploy with generated config
kubectl apply -f generated-deployment.yaml
```

### **Strategy 2: Dynamic Recipe Selection**
```yaml
# values.yaml
aim_engine:
  recipe:
    model_id: "Qwen/Qwen3-32B"
    auto_select: true
    fallback_enabled: true
```

### **Strategy 3: Recipe-Aware Helm Charts**
```bash
# Deploy with automatic recipe selection
helm install aim-engine ./helm \
  --set aim_engine.recipe.auto_select=true \
  --set aim_engine.recipe.model_id="Qwen/Qwen3-32B"
```

### **Strategy 4: Admission Controller Validation**
```yaml
# Validating webhook for recipe validation
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: aim-engine-recipe-validator
webhooks:
- name: recipe.aim-engine.com
  rules:
  - apiGroups: ["apps"]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["deployments"]
  clientConfig:
    service:
      namespace: aim-engine
      name: aim-engine-recipe-validator
      path: "/validate"
  failurePolicy: Fail
```

### **Strategy 5: Monitoring Integration**
```yaml
# ServiceMonitor for recipe metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: aim-engine-recipe-monitor
spec:
  selector:
    matchLabels:
      app: aim-engine
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

## **Recipe Selection Workflow**

### **Pre-Deployment Phase**
1. **Recipe Selection**: Choose optimal recipe based on model and resources
2. **Resource Validation**: Verify cluster can accommodate recipe requirements
3. **Configuration Generation**: Generate Kubernetes manifests from recipe
4. **Validation**: Validate configuration through admission controller

### **Deployment Phase**
1. **Resource Allocation**: Allocate resources based on recipe requirements
2. **Container Startup**: Start container with recipe-generated configuration
3. **Health Checks**: Verify deployment health and readiness
4. **Service Exposure**: Expose service endpoints

### **Post-Deployment Phase**
1. **Performance Monitoring**: Monitor performance against recipe targets
2. **Resource Utilization**: Track resource utilization
3. **Optimization**: Optimize based on monitoring data
4. **Scaling**: Scale based on demand and performance

### **Fallback Strategy**
```python
def fallback_strategy(primary_recipe, available_resources):
    # GPU count fallback
    if primary_recipe.gpu_count > available_resources.gpu_count:
        return try_lower_gpu_count(primary_recipe, available_resources)
    
    # Precision fallback
    if primary_recipe.precision not in available_resources.supported_precisions:
        return try_alternative_precision(primary_recipe)
    
    # Backend fallback
    if primary_recipe.backend not in available_resources.supported_backends:
        return try_alternative_backend(primary_recipe)
    
    # Default fallback
    return get_default_recipe(primary_recipe.model_id)
```

## **Benefits of Recipe-Based Kubernetes Deployment**

### **Performance Optimization**
- **Hardware-specific tuning** for AMD GPUs
- **Model-optimized configurations** based on size
- **Automatic resource scaling** based on requirements
- **Performance monitoring** against recipe targets

### **Operational Efficiency**
- **Consistent deployments** across environments
- **Reduced configuration errors** through validation
- **Automatic fallback strategies** for resource constraints
- **Zero-configuration deployments** with auto-selection

### **Resource Management**
- **Optimal resource allocation** based on model requirements
- **Efficient GPU utilization** through precision selection
- **Scalable configurations** that grow with hardware
- **Cost optimization** through right-sized deployments

### **Monitoring & Observability**
- **Recipe-aware metrics** for performance tracking
- **Resource utilization monitoring** based on recipe targets
- **Performance KPI tracking** for optimization
- **Automated alerting** based on recipe performance
