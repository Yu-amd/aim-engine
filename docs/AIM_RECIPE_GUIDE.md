# AIM Recipe Guide for AIM Engine

## Overview

This guide explains how to use **AIM (AMD Inference Microservice)** recipes with **AIM Engine** for intelligent, automated AI model deployment on AMD hardware.

## What are AIM Recipes?

AIM Recipes are YAML configuration files that define optimal deployment configurations for AI models on AMD hardware. They specify:

- **Model Information**: Model ID, Hugging Face ID, hardware requirements
- **Hardware Configuration**: Target GPU (MI250, MI300X), precision formats
- **Serving Configuration**: vLLM and/or SGLang settings for different GPU counts
- **Performance Parameters**: Batch sizes, memory utilization, context lengths

## Recipe Structure

### Basic Recipe Format

```yaml
# Basic Information
recipe_id: model-name-hardware-precision
model_id: Model/Name
huggingface_id: Model/Name
hardware: MI250  # or MI300X
precision: bf16  # fp16, bf16, fp8, int8, int4

# vLLM Serving Configurations
vllm_serve:
  "1_gpu":
    enabled: true
    args:
      --model: Model/Name
      --dtype: bfloat16
      --max-batch-size: "6"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"

  "2_gpu":
    enabled: true
    args:
      --model: Model/Name
      --dtype: bfloat16
      --tensor-parallel-size: "2"
      --max-batch-size: "12"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"

# SGLang Serving Configurations (optional)
sglang_serve:
  "1_gpu":
    enabled: true
    args:
      --model: Model/Name
      --dtype: bfloat16
      --max-batch-size: "3"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8001"
```

## Using AIM Recipes with AIM Engine

### 1. Automatic Recipe Selection

AIM Engine automatically discovers and uses AIM recipes:

```yaml
# AIM Engine Custom Resource
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen3-32b-inference
spec:
  model: Qwen/Qwen3-32B
  hardware: MI250
  precision: bf16
  gpuCount: 4
  servingEngine: vllm
```

**AIM Engine automatically**:
1. Finds `qwen3-32b-mi250-bf16.yaml` recipe
2. Applies 4-GPU configuration from recipe
3. Uses optimized vLLM settings
4. Deploys with intelligent caching

### 2. Manual Recipe Specification

You can specify a custom recipe:

```yaml
# AIM Engine with custom recipe
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: custom-model-inference
spec:
  model: Custom/Model-Name
  hardware: MI300X
  precision: fp8
  gpuCount: 2
  servingEngine: vllm
  customRecipe:
    recipePath: /path/to/custom-recipe.yaml
    # or inline recipe
    recipeContent: |
      recipe_id: custom-model-mi300x-fp8
      model_id: Custom/Model-Name
      hardware: MI300X
      precision: fp8
      vllm_serve:
        "2_gpu":
          enabled: true
          args:
            --model: Custom/Model-Name
            --dtype: float8
            --tensor-parallel-size: "2"
            --max-batch-size: "16"
            --max-context-len: "16384"
            --gpu-memory-utilization: "0.85"
            --port: "8000"
```

## Recipe Examples

### Example 1: Small Model (Llama-3-8B)

```yaml
# Recipe: llama-3-8b-mi250-fp16.yaml
recipe_id: llama-3-8b-mi250-fp16
model_id: meta-llama/Llama-3-8B-Instruct
huggingface_id: meta-llama/Llama-3-8B-Instruct
hardware: MI250
precision: fp16

vllm_serve:
  "1_gpu":
    enabled: true
    args:
      --model: meta-llama/Llama-3-8B-Instruct
      --dtype: float16
      --max-batch-size: "16"
      --max-context-len: "8192"
      --gpu-memory-utilization: "0.8"
      --trust-remote-code: "true"
      --port: "8000"

  "2_gpu":
    enabled: true
    args:
      --model: meta-llama/Llama-3-8B-Instruct
      --dtype: float16
      --tensor-parallel-size: "2"
      --max-batch-size: "24"
      --max-context-len: "8192"
      --gpu-memory-utilization: "0.8"
      --trust-remote-code: "true"
      --port: "8000"
```

**AIM Engine Usage**:
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: llama-3-8b-inference
spec:
  model: meta-llama/Llama-3-8B-Instruct
  hardware: MI250
  precision: fp16
  gpuCount: 1  # or 2 for better performance
  servingEngine: vllm
```

### Example 2: Large Model (Qwen3-32B)

```yaml
# Recipe: qwen3-32b-mi300x-bf16.yaml
recipe_id: qwen3-32b-mi300x-bf16
model_id: Qwen/Qwen3-32B
huggingface_id: Qwen/Qwen3-32B
hardware: MI300X
precision: bf16

vllm_serve:
  "2_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "2"
      --max-batch-size: "12"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"

  "4_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "4"
      --max-batch-size: "24"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"

  "8_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "8"
      --max-batch-size: "48"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
```

**AIM Engine Usage**:
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen3-32b-inference
spec:
  model: Qwen/Qwen3-32B
  hardware: MI300X
  precision: bf16
  gpuCount: 4  # or 2, 8 based on needs
  servingEngine: vllm
  autoScaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 2
```

### Example 3: Massive Model (Llama-3.1-405B)

```yaml
# Recipe: llama-3-1-405b-mi300x-fp8.yaml
recipe_id: llama-3-1-405b-mi300x-fp8
model_id: meta-llama/Llama-3.1-405B-Instruct
huggingface_id: meta-llama/Llama-3.1-405B-Instruct
hardware: MI300X
precision: fp8

vllm_serve:
  "8_gpu":
    enabled: true
    args:
      --model: meta-llama/Llama-3.1-405B-Instruct
      --dtype: float8
      --tensor-parallel-size: "8"
      --max-batch-size: "64"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
```

**AIM Engine Usage**:
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: llama-3-1-405b-inference
spec:
  model: meta-llama/Llama-3.1-405B-Instruct
  hardware: MI300X
  precision: fp8
  gpuCount: 8
  servingEngine: vllm
  resources:
    requests:
      nvidia.com/gpu: 8
    limits:
      nvidia.com/gpu: 8
```

## Recipe Customization

### 1. Parameter Overrides

Override specific recipe parameters:

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: custom-qwen3-32b
spec:
  model: Qwen/Qwen3-32B
  hardware: MI300X
  precision: bf16
  gpuCount: 4
  servingEngine: vllm
  customArgs:
    --max-batch-size: "32"  # Override recipe default (24)
    --max-context-len: "16384"  # Override recipe default (32768)
    --gpu-memory-utilization: "0.95"  # Override recipe default (0.9)
```

### 2. Multi-Engine Deployment

Use both vLLM and SGLang from recipe:

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen3-32b-multi-engine
spec:
  model: Qwen/Qwen3-32B
  hardware: MI250
  precision: bf16
  gpuCount: 2
  servingEngines:
    - vllm
    - sglang
  engineConfig:
    vllm:
      port: 8000
      customArgs:
        --max-batch-size: "16"
    sglang:
      port: 8001
      customArgs:
        --max-batch-size: "8"
```

### 3. Advanced Configuration

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: advanced-qwen3-32b
spec:
  model: Qwen/Qwen3-32B
  hardware: MI300X
  precision: bf16
  gpuCount: 4
  servingEngine: vllm
  customArgs:
    --max-batch-size: "32"
    --max-context-len: "16384"
    --gpu-memory-utilization: "0.95"
    --quantization: "awq"  # Add quantization
    --enforce-eager: "true"  # Force eager mode
  resources:
    requests:
      memory: "64Gi"
      cpu: "8"
    limits:
      memory: "128Gi"
      cpu: "16"
  autoScaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

## Recipe Validation

### 1. Manual Validation

Validate recipes before using with AIM Engine:

```bash
# Validate single recipe
python3 validate_aim_recipe_yaml.py recipes/qwen3-32b-mi250-bf16.yaml

# Validate all recipes
python3 validate_aim_recipe_yaml.py --all

# Validate with custom directory
python3 validate_aim_recipe_yaml.py --recipes-dir /path/to/recipes
```

### 2. AIM Engine Validation

AIM Engine automatically validates recipes:

```bash
# Deploy with automatic validation
kubectl apply -f aimendpoint.yaml

# Check validation status
kubectl describe aimendpoint qwen3-32b-inference -n aim-engine

# View validation logs
kubectl logs -n aim-engine deployment/aim-engine-operator
```

## Best Practices

### 1. Recipe Selection

- **Use Standard Models**: Prefer models with existing recipes
- **Hardware Matching**: Ensure hardware matches available GPUs
- **Precision Optimization**: Choose precision based on needs:
  - `bf16`: Best quality, good performance
  - `fp16`: Good balance of quality and performance
  - `fp8`: High performance, good quality
  - `int8`: High performance, reduced quality
  - `int4`: Maximum performance, reduced quality

### 2. GPU Count Selection

| Model Size | Recommended GPU Count | Hardware |
|------------|----------------------|----------|
| < 7B       | 1-2                  | MI250/MI300X |
| 7B-32B     | 2-4                  | MI250/MI300X |
| 32B-70B    | 4-8                  | MI300X |
| > 70B      | 8                    | MI300X |

### 3. Performance Tuning

```yaml
# For low latency
customArgs:
  --max-batch-size: "1"
  --max-context-len: "4096"

# For high throughput
customArgs:
  --max-batch-size: "48"
  --max-context-len: "32768"
  --gpu-memory-utilization: "0.95"

# For memory-constrained environments
customArgs:
  --max-batch-size: "4"
  --gpu-memory-utilization: "0.7"
  --dtype: "int8"
```

### 4. Production Deployment

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: production-qwen3-32b
spec:
  model: Qwen/Qwen3-32B
  hardware: MI300X
  precision: bf16
  gpuCount: 4
  servingEngine: vllm
  replicas: 2  # High availability
  autoScaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
  resources:
    requests:
      memory: "64Gi"
      cpu: "8"
    limits:
      memory: "128Gi"
      cpu: "16"
  healthCheck:
    enabled: true
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  monitoring:
    enabled: true
    metrics:
      - requests_per_second
      - latency_p95
      - gpu_utilization
      - memory_usage
```

## Troubleshooting

### Common Issues

#### Recipe Not Found
```bash
# Check available recipes
kubectl get aimrecipe -n aim-engine

# Verify model compatibility
kubectl describe aimrecipe <recipe-name>

# Check recipe validation
python3 validate_aim_recipe_yaml.py <recipe-file>
```

#### Performance Issues
```bash
# Check resource allocation
kubectl top pods -n aim-engine

# Verify GPU utilization
rocm-smi  # for AMD GPUs

# Check serving engine logs
kubectl logs -n aim-engine deployment/<aim-name>
```

#### Memory Errors
```yaml
# Reduce memory usage
customArgs:
  --max-batch-size: "4"
  --gpu-memory-utilization: "0.7"
  --dtype: "int8"
```

#### Validation Errors
```bash
# Check recipe syntax
python3 validate_aim_recipe_yaml.py recipe.yaml

# Verify file naming
recipe_id: should-match-filename

# Ensure model IDs are consistent
model_id: should-match-huggingface_id
```

## Creating Custom Recipes

### 1. Recipe Template

```yaml
# Template: custom-model-template.yaml
recipe_id: {model-name}-{hardware}-{precision}
model_id: {Model/Name}
huggingface_id: {Model/Name}
hardware: {MI250|MI300X}
precision: {fp16|bf16|fp8|int8|int4}

vllm_serve:
  "1_gpu":
    enabled: true
    args:
      --model: {Model/Name}
      --dtype: {float16|bfloat16|float8|int8|int4}
      --max-batch-size: "{batch-size}"
      --max-context-len: "{context-length}"
      --gpu-memory-utilization: "{memory-utilization}"
      --trust-remote-code: "true"
      --port: "8000"
```

### 2. Recipe Creation Process

1. **Model Analysis**: Determine model size and requirements
2. **Hardware Selection**: Choose appropriate GPU and precision
3. **Parameter Tuning**: Optimize batch size, context length, memory
4. **Validation**: Test recipe with validation scripts
5. **Documentation**: Document any custom configurations

### 3. Example Custom Recipe

```yaml
# Custom recipe for new model
recipe_id: custom-model-mi300x-bf16
model_id: Custom/New-Model-32B
huggingface_id: Custom/New-Model-32B
hardware: MI300X
precision: bf16

vllm_serve:
  "2_gpu":
    enabled: true
    args:
      --model: Custom/New-Model-32B
      --dtype: bfloat16
      --tensor-parallel-size: "2"
      --max-batch-size: "8"
      --max-context-len: "16384"
      --gpu-memory-utilization: "0.85"
      --trust-remote-code: "true"
      --port: "8000"

  "4_gpu":
    enabled: true
    args:
      --model: Custom/New-Model-32B
      --dtype: bfloat16
      --tensor-parallel-size: "4"
      --max-batch-size: "16"
      --max-context-len: "16384"
      --gpu-memory-utilization: "0.85"
      --trust-remote-code: "true"
      --port: "8000"
```

## Resources

### Documentation
- [AIM Definition](AIM_DEFINITION.md) - Comprehensive AIM framework overview
- [AIM Engine Integration](AIM_ENGINE_INTEGRATION.md) - Integration details
- [Recipe Guide](RECIPE_GUIDE.md) - General recipe documentation
- [API Reference](API.md) - AIM Engine API documentation

### Examples
- [Basic Recipes](../examples/kubernetes/basic-aim/) - Simple recipe examples
- [Advanced Recipes](../examples/kubernetes/scalable-aim/) - Advanced configurations
- [Custom Recipes](../examples/kubernetes/multi-model/) - Custom recipe examples

### Tools
- [Recipe Validator](../src/aim_engine/validation/) - Validation tools
- [Recipe Templates](../config/recipes/) - Recipe templates
- [Performance Monitor](../src/aim_engine/monitoring/) - Monitoring tools

---

*Last updated: January 2025* 