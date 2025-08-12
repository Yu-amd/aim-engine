# AIM (AMD Inference Microservice) Definition

## Introduction

**AIM (AMD Inference Microservice)** is a comprehensive framework for deploying and serving AI models on AMD hardware, specifically designed for AMD Instinct™ GPUs (MI250, MI300X, MI325X, MI355X, etc.). AIM provides standardized recipes and configurations for efficient model inference across different hardware configurations and precision formats.

### Key Features
- **Hardware Optimization**: Tailored configurations for AMD Instinct™ GPUs
- **Multi-Precision Support**: FP16, BF16, FP8, INT8, INT4 precision formats
- **Scalable Deployment**: Support for 1-8 GPU configurations
- **Multiple Serving Engines**: vLLM and SGLang serving options
- **Standardized Recipes**: Consistent configuration patterns
- **Validation Framework**: Comprehensive validation and testing

## AIM Architecture

### Core Components

The AIM framework consists of several key components:

1. **Model Catalog**: YAML files defining model metadata and specifications
2. **Recipe Catalog**: YAML files defining deployment configurations
3. **Validation Scripts**: Python scripts for validating configurations
4. **Serving Engines**: vLLM and SGLang integration
5. **Hardware Support**: MI250 and MI300X GPU configurations

### Directory Structure
```
config/
├── models/                    # Model catalog YAML files
├── recipes/                   # AIM recipe YAML files
├── templates/                 # Template files
└── aim_recipe_schema.json     # Schema files

src/aim_engine/
├── aim_recipe_selector.py     # Recipe selection and validation
├── aim_config_generator.py    # Configuration generation
├── aim_cache_manager.py       # Cache management
└── aim_generate_command.py    # Command generation
```

## AIM Recipes

### What are AIM Recipes?

AIM Recipes are YAML configuration files that define how to deploy and serve AI models on AMD hardware. Each recipe specifies:
           
- **Model Information**: Model ID, Hugging Face ID
- **Hardware Configuration**: Target GPU (MI250, MI300X)
- **Precision Format**: FP16, BF16, FP8, INT8, INT4
- **Serving Configuration**: vLLM and/or SGLang settings
- **GPU Scaling**: 1-8 GPU configurations with tensor parallelism

### Recipe Naming Convention

```
{model-name}-{hardware}-{precision}.yaml

Examples:
├── qwen3-32b-mi250-bf16.yaml
├── llama-3-1-405b-fp8-kv-mi300x-fp8.yaml
├── deepseek-r1-0528-mi250-fp16.yaml
└── llama-4-maverick-17b-mi300x-fp8.yaml
```

## Supported Hardware

### AMD Instinct™ MI250
- **Memory**: 128GB HBM2e
- **FP16 Performance**: Up to 383 TFLOPS
- **Best For**: Large models, high throughput
- **Configurations**: 1, 2, 4, 8 GPU setups

### AMD Instinct™ MI300X
- **Memory**: 192GB HBM3
- **FP16 Performance**: Up to 1.3 PFLOPS
- **Best For**: Massive models, maximum performance
- **Configurations**: 1, 2, 4, 8 GPU setups

### Hardware Selection Guide

| Model Size | Recommended Hardware | Precision | GPU Count |
|------------|---------------------|-----------|-----------|
| < 7B       | MI250               | FP16      | 1-2       |
| 7B-32B     | MI250/MI300X        | BF16/FP16 | 1-4       |
| 32B-70B    | MI300X              | BF16/FP8  | 2-8       |
| > 70B      | MI300X              | FP8/INT8  | 4-8       |

## Precision Formats

### Supported Formats

| Format | Bits | Memory Usage | Performance | Quality | Use Case |
|--------|------|--------------|-------------|---------|----------|
| FP16   | 16   | 2x FP32      | High        | Good    | General inference |
| BF16   | 16   | 2x FP32      | High        | Good    | Training/inference |
| FP8    | 8    | 4x FP32      | Very High   | Good    | High-throughput |
| INT8   | 8    | 4x FP32      | Very High   | Fair    | Quantized models |
| INT4   | 4    | 8x FP32      | Highest     | Fair    | Memory-constrained |

### Precision Selection Guide

```yaml
# For maximum quality
precision: bf16

# For maximum performance
precision: fp8

# For memory-constrained environments
precision: int8

# For extreme memory constraints
precision: int4
```

## Serving Engines

### vLLM Serving

**vLLM** is a high-performance inference engine optimized for large language models.

#### Key Features
- **PagedAttention**: Efficient memory management
- **Continuous Batching**: Dynamic batch processing
- **Tensor Parallelism**: Multi-GPU scaling
- **High Throughput**: Optimized for production workloads

#### Configuration Example
```yaml
vllm_serve:
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
```

### SGLang Serving

**SGLang** is a structured generation language and serving framework.

#### Key Features
- **Structured Generation**: Complex reasoning workflows
- **Function Calling**: Tool integration
- **Streaming**: Real-time response generation
- **Flexible Control**: Advanced generation control

#### Configuration Example
```yaml
sglang_serve:
  "2_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "2"
      --max-batch-size: "6"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8001"
```

## Recipe Structure

### Complete Recipe Example

```yaml
# Basic Information
recipe_id: qwen3-32b-mi250-bf16
model_id: Qwen/Qwen3-32B
huggingface_id: Qwen/Qwen3-32B
hardware: MI250
precision: bf16

# vLLM Serving Configurations
vllm_serve:
  "1_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --max-batch-size: "6"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"

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

# SGLang Serving Configurations
sglang_serve:
  "1_gpu":
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --max-batch-size: "3"
      --max-context-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8001"
```

### Key Configuration Parameters

#### Model Parameters
- `--model`: Hugging Face model identifier
- `--dtype`: Data type (bfloat16, float16, float8, int8, int4)
- `--trust-remote-code`: Enable custom model code

#### Performance Parameters
- `--max-batch-size`: Maximum concurrent requests
- `--max-context-len`: Maximum sequence length
- `--gpu-memory-utilization`: GPU memory usage (0.0-1.0)

#### Scaling Parameters
- `--tensor-parallel-size`: Number of GPUs for tensor parallelism
- `--port`: Serving port number

## AIM Engine Integration

### What is AIM Engine?

**AIM Engine** is an intelligent AI model deployment system that automatically optimizes large language model serving on AMD hardware. It combines intelligent recipe selection, dynamic resource detection, and advanced caching to deliver optimal performance with zero configuration, serving as the essential dependency management and orchestration layer for AIM deployments.

### Key Value Propositions
- **Zero Configuration**: Works out-of-the-box with automatic optimization
- **Hardware Intelligence**: AMD GPU-aware optimization and resource allocation
- **Performance Optimization**: Up to 10x faster deployment with intelligent caching
- **Enterprise Ready**: Kubernetes, Helm, and KServe integration
- **Streaming Support**: Real-time response streaming for enhanced UX
- **Dependency Management**: Ensures all AIM deployment dependencies are met

### Technical Highlights
- **Unified Container**: AIM Engine tools integrated into vLLM ROCm container
- **Intelligent Caching**: Persistent model caching with significant speed improvement
- **Dynamic Optimization**: Model-size based GPU allocation and precision selection
- **Multi-Backend Support**: vLLM, SGLang, and extensible backend architecture
- **Production Ready**: Comprehensive monitoring, logging, and health checks
- **Dependency Orchestration**: Manages all AIM deployment prerequisites and requirements

## Validation and Management

### Recipe Validation

#### Python Validation Script
```bash
# Validate a single recipe using AIM Engine
python3 src/aim_engine/aim_recipe_selector.py --validate --recipe config/recipes/qwen3-32b-mi250-bf16.yaml

# Validate all recipes in config directory
python3 src/aim_engine/aim_recipe_selector.py --validate --recipes-dir config/recipes

# Validate recipes in custom directory
python3 src/aim_engine/aim_recipe_selector.py --validate --recipes-dir /path/to/recipes
```

#### Validation Checks
- **Schema Compliance**: YAML structure validation
- **ID Consistency**: Recipe ID matches filename
- **Model Consistency**: Model ID and Hugging Face ID alignment
- **Serving Configuration**: At least one serving method enabled
- **GPU Configuration**: Tensor parallelism matches GPU count

### Model Catalog Management

#### Model Validation
```bash
# Validate a single model using AIM Engine
python3 src/aim_engine/aim_recipe_selector.py --validate-model --model config/models/qwen3-32b.yaml

# Validate all models in config directory
python3 src/aim_engine/aim_recipe_selector.py --validate-models --models-dir config/models
```

#### Model Card Fetching
```bash
# Fetch model cards from Hugging Face (using AIM Engine tools)
python3 src/aim_engine/aim_recipe_selector.py --fetch-model-cards --models-dir config/models

# With API token for better rate limits
export HF_TOKEN=your_token
python3 src/aim_engine/aim_recipe_selector.py --fetch-model-cards --models-dir config/models
```

## Best Practices

### Recipe Creation

1. **Use Templates**: Start with existing recipe templates
2. **Follow Naming Convention**: `{model}-{hardware}-{precision}.yaml`
3. **Test Configurations**: Validate all GPU configurations
4. **Optimize Parameters**: Tune batch size and memory utilization
5. **Document Changes**: Add comments for custom configurations

### Performance Optimization

#### Memory Management
```yaml
# Conservative memory usage
--gpu-memory-utilization: "0.7"

# Aggressive memory usage
--gpu-memory-utilization: "0.95"
```

#### Batch Size Tuning
```yaml
# For low latency
--max-batch-size: "1"

# For high throughput
--max-batch-size: "48"
```

#### Context Length Optimization
```yaml
# For short conversations
--max-context-len: "4096"

# For long documents
--max-context-len: "32768"
```

### Hardware Selection

#### MI250 Recommendations
- **Small Models (< 7B)**: 1-2 GPUs, FP16
- **Medium Models (7B-32B)**: 2-4 GPUs, BF16
- **Large Models (32B+)**: 4-8 GPUs, FP8

#### MI300X Recommendations
- **Medium Models (7B-32B)**: 1-2 GPUs, BF16
- **Large Models (32B-70B)**: 2-4 GPUs, FP8
- **Massive Models (70B+)**: 4-8 GPUs, INT8

## Examples

### Example 1: Small Model on MI250

```yaml
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
      --port: "8000"
```

### Example 2: Large Model on MI300X

```yaml
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
      --port: "8000"
```

### Example 3: Mixed Precision Configuration

```yaml
recipe_id: deepseek-r1-mi300x-mixed
model_id: deepseek-ai/DeepSeek-R1-0528
huggingface_id: deepseek-ai/DeepSeek-R1-0528
hardware: MI300X
precision: mixed

vllm_serve:
  "4_gpu":
    enabled: true
    args:
      --model: deepseek-ai/DeepSeek-R1-0528
      --dtype: bfloat16
      --tensor-parallel-size: "4"
      --max-batch-size: "32"
      --max-context-len: "16384"
      --gpu-memory-utilization: "0.85"
      --quantization: "awq"
      --port: "8000"
```

## Troubleshooting

### Common Issues

#### Memory Errors
```bash
# Reduce batch size
--max-batch-size: "4"

# Reduce memory utilization
--gpu-memory-utilization: "0.7"

# Use lower precision
--dtype: int8
```

#### Performance Issues
```bash
# Increase batch size for throughput
--max-batch-size: "32"

# Use tensor parallelism
--tensor-parallel-size: "4"

# Optimize memory usage
--gpu-memory-utilization: "0.95"
```

#### Validation Errors
```bash
# Check schema compliance
python3 src/aim_engine/aim_recipe_selector.py --validate --recipe recipe.yaml

# Verify file naming
recipe_id: should-match-filename

# Ensure model IDs are consistent
model_id: should-match-huggingface_id
```

### Debug Mode

Enable debug logging for detailed information:
```bash
export AIM_DEBUG=true
python3 src/aim_engine/aim_recipe_selector.py --validate --recipes-dir config/recipes
```

## Future Enhancements

### Planned Features
- **Auto-tuning**: Automatic parameter optimization
- **Multi-model Serving**: Multiple models on single hardware
- **Dynamic Scaling**: Automatic GPU allocation
- **Performance Monitoring**: Real-time metrics and alerts
- **Cloud Integration**: AWS, Azure, GCP deployment support

### Community Contributions
- **New Hardware Support**: Additional AMD GPU models
- **Serving Engine Integration**: New inference engines
- **Model Optimizations**: Custom model configurations
- **Tooling Improvements**: Enhanced validation and management tools

## Resources

### Documentation
- [AIM Recipe Schema](../config/aim_recipe_schema.json)
- [Model Catalog Schema](../config/models/) - Model catalog directory
- [Validation Scripts](../src/aim_engine/) - AIM Engine validation tools

### Tools
- [Recipe Validator](../src/aim_engine/aim_recipe_selector.py) - Recipe selection and validation
- [Model Validator](../config/models/) - Model validation tools
- [Model Card Fetcher](../config/models/) - Model catalog management

### Templates
- [Recipe Template](../config/templates/) - Recipe templates directory
- [Blueprint Template](../config/templates/) - Blueprint templates directory

---

*Last updated: July 2025* 
