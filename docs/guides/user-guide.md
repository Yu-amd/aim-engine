# AIM Engine User Guide

## 🎯 **Overview**

AIM Engine is an intelligent AI model deployment system that automatically detects AMD GPUs and selects optimal configurations for model deployment. This guide covers how to use AIM Engine effectively.

## 🚀 **Quick Start**

### **1. Basic Model Launch**

```bash
# Launch with auto-detection (recommended)
aim-engine launch Qwen/Qwen3-32B

# Launch with specific GPU count
aim-engine launch Qwen/Qwen3-32B 4

# Launch with specific precision
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16
```

### **2. Direct vLLM Serving**

```bash
# Serve model directly (bypasses orchestration)
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4

# Serve with custom port
aim-engine serve Llama-3-8B --tensor-parallel-size 2 --port 8001
```

## 📋 **Core Commands**

### **Model Launch**

```bash
# Basic launch with auto-detection
aim-engine launch <model-name>

# Launch with specific GPU count
aim-engine launch <model-name> <gpu-count>

# Launch with specific precision
aim-engine launch <model-name> <gpu-count> --precision <precision>

# Launch with custom cache directory
aim-engine launch <model-name> <gpu-count> --cache-dir /custom/cache

# Launch without cache (not recommended)
aim-engine launch <model-name> <gpu-count> --no-cache
```

### **Model Serving**

```bash
# Serve model directly
aim-engine serve <model-name> --tensor-parallel-size <gpu-count>

# Serve with custom port
aim-engine serve <model-name> --tensor-parallel-size <gpu-count> --port <port>

# Serve with specific precision
aim-engine serve <model-name> --tensor-parallel-size <gpu-count> --precision <precision>
```

### **Model Management**

```bash
# List running models
aim-engine list

# Get model status
aim-engine status <container-name>

# Stop a model
aim-engine stop <container-name>

# Test model endpoint
aim-engine test <container-name>
```

## 🔧 **Configuration**

### **Environment Variables**

```bash
# Cache configuration
export AIM_CACHE_DIR=/workspace/model-cache
export AIM_CACHE_ENABLED=1
export HF_HOME=/workspace/model-cache
export TRANSFORMERS_CACHE=/workspace/model-cache
export VLLM_CACHE_DIR=/workspace/model-cache

# Performance optimization for AMD ROCm
export PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512
export HF_HUB_DISABLE_TELEMETRY=1

# GPU configuration
export ROCR_VISIBLE_DEVICES=0,1,2,3
```

### **Configuration Files**

```yaml
# aim-config.yaml
cache:
  enabled: true
  directory: /workspace/model-cache
  cleanup_days: 30

gpu:
  auto_detect: true
  max_gpus: 8
  memory_fraction: 0.9

models:
  default_precision: bf16
  tensor_parallel: true
  max_model_size: 70B
```

## 📊 **Performance Optimization**

### **GPU Memory Management**

```bash
# Check available GPU memory
rocm-smi --showmemuse

# Monitor GPU usage
watch -n 1 'rocm-smi --showuse'

# Optimize memory allocation
export PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512
```

### **Model Precision**

```bash
# Use BF16 for better performance (recommended)
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# Use FP16 for memory efficiency
aim-engine launch Qwen/Qwen3-32B 4 --precision fp16

# Use FP32 for maximum accuracy
aim-engine launch Qwen/Qwen3-32B 4 --precision fp32
```

### **Tensor Parallelism**

```bash
# Use all available GPUs
aim-engine launch Qwen/Qwen3-32B 8

# Use subset of GPUs
aim-engine launch Qwen/Qwen3-32B 4

# Single GPU deployment
aim-engine launch Llama-3-8B 1
```

## 🔍 **Monitoring and Debugging**

### **Model Status**

```bash
# Check running models
aim-engine list

# Get detailed status
aim-engine status aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Check model logs
docker logs aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **GPU Monitoring**

```bash
# Check GPU availability
rocm-smi

# Monitor GPU usage
rocm-smi --showuse

# Check GPU temperature
rocm-smi --showtemp

# Real-time monitoring
watch -n 1 'rocm-smi --showuse && rocm-smi --showtemp'
```

### **Cache Monitoring**

```bash
# Check cache status
aim-engine cache stats

# List cached models
aim-engine cache list

# Monitor cache usage
du -sh /workspace/model-cache
ls -la /workspace/model-cache/models/
```

## 🐳 **Docker Integration**

### **Container Deployment**

```bash
# Deploy with Docker
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4
```

### **Docker Compose**

```yaml
# docker-compose.yml
version: '3.8'
services:
  aim-engine:
    image: aim-engine:latest
    environment:
      - AIM_CACHE_DIR=/workspace/model-cache
      - AIM_CACHE_ENABLED=1
      - PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512
    volumes:
      - /workspace/model-cache:/workspace/model-cache
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "8000:8000"
    deploy:
      resources:
        reservations:
          devices:
            - driver: amd
              count: 4
              capabilities: [gpu]
```

## 🔧 **Troubleshooting**

### **Common Issues**

#### **1. GPU Memory Issues**

```bash
# Check available memory
rocm-smi --showmemuse

# Reduce GPU count
aim-engine launch Qwen/Qwen3-32B 2  # Use 2 GPUs instead of 4

# Use lower precision
aim-engine launch Qwen/Qwen3-32B 4 --precision fp16
```

#### **2. Model Download Failures**

```bash
# Check network connectivity
curl -I https://huggingface.co/Qwen/Qwen3-32B

# Use alternative mirror
export HF_ENDPOINT=https://hf-mirror.com

# Clear corrupted cache
rm -rf /workspace/model-cache/models/Qwen--Qwen3-32B/
```

#### **3. Container Issues**

```bash
# Check container status
docker ps -a

# Check container logs
docker logs aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Restart container
docker restart aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Error Messages**

#### **"ROCm out of memory"**
```bash
# Reduce GPU count or use lower precision
aim-engine launch Qwen/Qwen3-32B 2 --precision fp16
```

#### **"Model not found"**
```bash
# Check model name
curl -I https://huggingface.co/Qwen/Qwen3-32B

# Clear cache and retry
aim-engine cache remove Qwen/Qwen3-32B
aim-engine launch Qwen/Qwen3-32B 4
```

#### **"GPU not available"**
```bash
# Check GPU availability
rocm-smi

# Install ROCm drivers if needed
sudo apt install rocm-dkms
```

## 📚 **Advanced Usage**

### **Custom Recipes**

```yaml
# custom-recipe.yaml
model:
  name: Qwen/Qwen3-32B
  precision: bf16
  tensor_parallel: 4

deployment:
  container_name: custom-qwen-32b
  port: 8000
  health_check: true

optimization:
  max_batch_size: 32
  max_seq_len: 4096
  gpu_memory_utilization: 0.9
```

### **Batch Processing**

```bash
# Launch multiple models
aim-engine launch Qwen/Qwen3-32B 4 &
aim-engine launch Llama-3-8B 2 &
aim-engine launch Mistral-7B 2 &

# Wait for all models
wait

# Check all models
aim-engine list
```

### **Production Deployment**

```bash
# Use production configuration
export AIM_PRODUCTION_MODE=1
export AIM_LOG_LEVEL=INFO

# Launch with health checks
aim-engine launch Qwen/Qwen3-32B 4 --health-check

# Monitor with external tools
rocm-smi --showuse
```

## 🎯 **Best Practices**

### **1. Resource Management**
- Use appropriate GPU count for model size
- Monitor memory usage with `rocm-smi --showmemuse`
- Use BF16 precision for optimal performance
- Enable caching for faster deployments

### **2. Performance Optimization**
- Use tensor parallelism for large models
- Optimize batch sizes for your use case
- Monitor GPU utilization with `rocm-smi --showuse`
- Use appropriate precision settings

### **3. Reliability**
- Enable health checks in production
- Monitor model logs regularly
- Use cache for faster recovery
- Implement proper error handling

## 📖 **Additional Resources**

- **[Complete Documentation](docs/README.md)**
- **[Container Guide](docs/guides/unified-container-cache.md)**
- **[Installation Guide](docs/guides/installation.md)**
- **[Troubleshooting Guide](docs/examples/troubleshooting.md)**

---

**AIM Engine** - AMD Inference Microservice! 🚀 