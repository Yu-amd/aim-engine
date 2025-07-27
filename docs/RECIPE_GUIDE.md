# AIM Recipe Development Guide

## Overview

AIM (AMD Inference Microservice) Recipes are YAML configuration files that define how to deploy and serve AI models on AMD hardware. This guide covers the complete process of creating, validating, and maintaining AIM recipes.

## Recipe Structure

### Basic Recipe Template

```yaml
recipe_id: model-name-hardware-precision
huggingface_id: "Model/Name"
precision: "bf16"  # bf16, fp16, fp8, int8, int4
hardware: "mi300x"  # mi300x, mi325x
description: "Brief description of the model and configuration"

vllm_serve:
  1_gpu:
    enabled: true
    args:
      --model: "Model/Name"
      --dtype: "bfloat16"
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
  
  2_gpu:
    enabled: true
    args:
      --model: "Model/Name"
      --dtype: "bfloat16"
      --tensor-parallel-size: "2"
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
```

## Naming Conventions

### Recipe ID Format
```
{model-name}-{hardware}-{precision}.yaml

Examples:
├── qwen3-32b-mi300x-bf16.yaml
├── llama-3-1-405b-mi300x-fp8.yaml

└── llama-4-maverick-17b-mi300x-fp8.yaml
```

## GPU Configuration

### Supported GPU Counts
AIM Engine supports configurations for 1, 2, 4, and 8 GPUs:

```yaml
vllm_serve:
  1_gpu:    # Single GPU configuration
  2_gpu:    # 2-GPU tensor parallelism
  4_gpu:    # 4-GPU tensor parallelism
  8_gpu:    # 8-GPU tensor parallelism
```

### Tensor Parallelism
For multi-GPU configurations, include the `--tensor-parallel-size` argument:

```yaml
2_gpu:
  enabled: true
  args:
    --tensor-parallel-size: "2"  # Must match GPU count
    # ... other arguments
```

## Backend-Specific Configuration

### vLLM Configuration

#### Required Arguments
```yaml
args:
  --model: "Model/Name"                    # Hugging Face model ID
  --dtype: "bfloat16"                      # Precision format
  --max-model-len: "32768"                 # Maximum sequence length
  --gpu-memory-utilization: "0.9"          # GPU memory usage
  --trust-remote-code: "true"              # Trust model code
  --port: "8000"                           # Service port
```

#### Optional Arguments
```yaml
args:
  --tensor-parallel-size: "2"              # For multi-GPU
  --max-num-batched-tokens: "8192"         # Batch size
  --max-num-seqs: "256"                    # Max concurrent sequences
  --block-size: "16"                       # KV cache block size
  --swap-space: "4"                        # CPU swap space (GB)
  --disable-log-stats: "true"              # Disable logging
```

## Model-Specific Considerations

### Large Models (32B+)
```yaml
# High memory utilization
--gpu-memory-utilization: "0.9"

# Large sequence length
--max-model-len: "32768"

# Conservative batch size
--max-num-batched-tokens: "4096"
```

### Small Models (7B-13B)
```yaml
# Lower memory utilization
--gpu-memory-utilization: "0.8"

# Standard sequence length
--max-model-len: "16384"

# Larger batch size
--max-num-batched-tokens: "8192"
```

## Recipe Validation

### Manual Validation Checklist
- [ ] Recipe ID follows naming convention
- [ ] All required fields are present
- [ ] Hugging Face ID is valid
- [ ] Precision format is supported
- [ ] Hardware identifier is correct
- [ ] GPU configurations are complete (1, 2, 4, 8 GPUs)
- [ ] Tensor parallelism matches GPU count
- [ ] vLLM arguments are valid
- [ ] Port numbers are consistent
- [ ] Memory utilization is appropriate

### Testing Recipes
```bash
# Test with 1 GPU
aim-engine launch Model/Name 1 --recipe your-recipe.yaml

# Test with 2 GPUs
aim-engine launch Model/Name 2 --recipe your-recipe.yaml

# Test endpoint health
curl http://localhost:8000/health
```

## Common Patterns

### Standard vLLM Recipe
```yaml
recipe_id: standard-model-mi300x-bf16
huggingface_id: "Model/Name"
precision: "bf16"
hardware: "mi300x"
description: "Standard configuration for Model/Name on MI300X"

vllm_serve:
  1_gpu:
    enabled: true
    args:
      --model: "Model/Name"
      --dtype: "bfloat16"
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
  
  2_gpu:
    enabled: true
    args:
      --model: "Model/Name"
      --dtype: "bfloat16"
      --tensor-parallel-size: "2"
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
```

## Troubleshooting

### Common Issues
1. **Invalid vLLM Arguments**: Use `--max-model-len` instead of `--max-batch-size`
2. **GPU Count Mismatch**: Ensure GPU detection is working correctly
3. **Memory Issues**: Reduce `--gpu-memory-utilization` or `--max-model-len`
4. **Port Conflicts**: Change port number or stop conflicting services

### Debug Mode
```bash
# Enable debug mode for detailed information
export AIM_DEBUG=1
aim-engine launch Model/Name 8
```

## Best Practices

### Recipe Design
1. **Consistency**: Use consistent naming and structure across recipes
2. **Completeness**: Include all GPU configurations (1, 2, 4, 8 GPUs)
3. **Validation**: Always validate recipes before deployment
4. **Documentation**: Include clear descriptions and tags
5. **Testing**: Test recipes on actual hardware before production

### Performance Optimization
1. **Memory Utilization**: Balance memory usage with performance
2. **Batch Sizes**: Optimize batch sizes for your use case
3. **Sequence Lengths**: Choose appropriate sequence lengths
4. **Precision**: Use the highest precision that fits in memory
