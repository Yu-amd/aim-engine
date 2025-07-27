# AIM Engine Recipe Implications for Kubernetes

## **Key Implications**

This document summarizes the key implications of AIM Engine's recipe selection system for Kubernetes deployment.

## **Core Implications**

### **Dynamic Resource Allocation**
- **GPU Count**: Automatically determined based on model size and available hardware
- **Memory Requirements**: Scaled proportionally with GPU count and model size
- **CPU Allocation**: Optimized based on GPU count and workload requirements
- **Storage**: Model-specific cache requirements

### **Performance Optimization**
- **Precision Selection**: Automatic choice between bf16, fp16, fp8 based on model and hardware
- **Batch Size Optimization**: Dynamic adjustment based on available memory
- **Model Length Configuration**: Optimized for specific model characteristics
- **Hardware-Specific Tuning**: AMD GPU optimizations (MI300X, MI325X)

### **Automatic Fallback**
- **GPU Count Fallback**: 8→4→2→1 GPU progression
- **Precision Fallback**: bf16→fp16→fp8 progression
- **Backend Fallback**: vLLM→SGLang progression
- **Resource Constraint Handling**: Automatic adjustment for cluster limitations

## **Recipe-to-Kubernetes Mapping**

### **Resource Mapping Matrix**
| Recipe Component | Kubernetes Resource | Mapping Logic |
|------------------|-------------------|---------------|
| `gpu_count` | `amd.com/gpu` | Direct mapping |
| `memory` | `memory` | GPU count × base memory |
| `cpu` | `cpu` | GPU count × base CPU |
| `storage` | `persistentVolumeClaim` | Model-specific cache size |
| `precision` | `env.VLLM_DTYPE` | Direct mapping |
| `backend` | `command` | Backend-specific command |

### **Command Generation**
```yaml
# Recipe configuration
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
```

### **Environment Variable Mapping**
```yaml
# Recipe environment variables
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

## **Implementation Strategies**

### **1. Helm Chart Integration**
- **Dynamic Values**: Recipe parameters drive Helm values
- **Template Logic**: Kubernetes manifests generated from recipe data
- **Override Support**: Manual overrides for specific requirements
- **Validation**: Recipe validation before deployment

### **2. Admission Controller Validation**
- **Resource Validation**: Ensure cluster can accommodate recipe requirements
- **Compatibility Checking**: Verify recipe compatibility with cluster configuration
- **Performance Validation**: Validate performance constraints
- **Automatic Rejection**: Prevent invalid deployments

### **3. Monitoring Integration**
- **Recipe Metrics**: Track performance by recipe
- **Resource Monitoring**: Monitor utilization against recipe targets
- **Performance Alerts**: Alert when performance deviates from recipe expectations
- **Optimization Insights**: Provide recommendations based on recipe performance

## **Kubernetes Integration Points**

### **Deployment Configuration**
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
            memory: "64Gi"    # From recipe memory calculation
            cpu: "16"         # From recipe cpu calculation
          limits:
            amd.com/gpu: "4"
            memory: "128Gi"
            cpu: "32"
        command: ["python3", "-m", "vllm.entrypoints.openai.api_server"]
        args:                 # Generated from recipe config.args
        env:                  # Generated from recipe env_vars
```

### **Service Configuration**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: aim-engine-service
spec:
  ports:
  - port: 8000
    targetPort: 8000
  selector:
    app: aim-engine
```

### **Storage Configuration**
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
      storage: 500Gi  # From recipe storage requirements
```

## **Benefits**

### **Performance Optimization**
- **Hardware-Specific Tuning**: Recipes optimized for AMD GPUs
- **Model-Specific Configuration**: Tailored settings for each model
- **Automatic Optimization**: No manual tuning required
- **Performance Monitoring**: Track performance against recipe targets

### **Operational Efficiency**
- **Zero Configuration**: Automatic recipe selection
- **Consistent Deployments**: Same recipe = same configuration
- **Reduced Errors**: Validation prevents invalid configurations
- **Easy Scaling**: Recipe-based scaling strategies

### **Resource Management**
- **Optimal Allocation**: Resources allocated based on actual requirements
- **Efficient Utilization**: GPU and memory used optimally
- **Cost Optimization**: Right-sized deployments
- **Scalability**: Easy to scale with recipe-based configurations

## **Next Steps**

1. **Implement Recipe Selection**: Add recipe selection logic to deployment
2. **Add Validation**: Implement admission controller validation
3. **Set Up Monitoring**: Configure recipe-based monitoring
4. **Create Dashboards**: Build recipe performance dashboards
5. **Optimize Recipes**: Continuously improve recipe configurations

The recipe-based approach ensures optimal performance and resource utilization for every deployment! 