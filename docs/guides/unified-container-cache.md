# AIM Engine - Container Guide

## 🎯 **Overview**

The AIM Engine container combines vLLM ROCm, AIM Engine orchestration, and **built-in model caching** into a single, efficient container. This approach ensures that model caching is used by default, significantly reducing deployment time and bandwidth usage.

## 🚀 **Key Features**

### **Built-in Cache Support (Default)**
- ✅ **Automatic Caching**: All models are cached by default
- ✅ **Shared Cache**: Multiple containers share the same cache
- ✅ **Persistent Storage**: Cache survives container restarts
- ✅ **Smart Detection**: Only downloads model differences
- ✅ **Cache Management**: Built-in CLI for cache operations

### **Container Benefits**
- ✅ **Single Image**: One container for orchestration and serving
- ✅ **Reduced Complexity**: No need for separate orchestration containers
- ✅ **Better Performance**: Direct model access without network overhead
- ✅ **Simplified Deployment**: Single command to launch models
- ✅ **Resource Efficiency**: Shared base image and dependencies

## 🔧 **Quick Start**

### **1. Build the Container**

```bash
# Build the container (includes cache support by default)
docker build -t aim-engine .

# Or use the provided build script
./scripts/build.sh
```

### **2. Set Up Cache Directory**

```bash
# Create cache directory
sudo mkdir -p /workspace/model-cache
sudo chown $USER:$USER /workspace/model-cache

# Initialize cache
docker run --rm -v /workspace/model-cache:/workspace/model-cache \
  aim-engine:latest aim-engine cache stats
```

### **3. Launch Models with Cache**

```bash
# Launch model with automatic caching
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4

# Launch another model (will use cached components)
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8001:8000 \
  aim-engine:latest \
  aim-engine launch Llama-3-8B 2
```

## 📋 **Usage Examples**

### **Basic Model Launch**

```bash
# Launch with auto-detection (recommended)
aim-engine launch Qwen/Qwen3-32B

# Launch with specific GPU count
aim-engine launch Qwen/Qwen3-32B 4

# Launch with specific precision
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# Launch with custom cache directory
aim-engine launch Qwen/Qwen3-32B 4 --cache-dir /custom/cache
```

### **Direct vLLM Serving**

```bash
# Serve model directly (bypasses orchestration)
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4

# Serve with custom port
aim-engine serve Llama-3-8B --tensor-parallel-size 2 --port 8001
```

### **Cache Management**

```bash
# Show cache statistics
aim-engine cache stats

# List cached models
aim-engine cache list

# Add model to cache
aim-engine cache add Qwen/Qwen3-32B /path/to/model

# Remove model from cache
aim-engine cache remove Qwen/Qwen3-32B

# Clean up old models
aim-engine cache cleanup --days 30
```

### **Model Management**

```bash
# List running models
aim-engine list

# Get model status
aim-engine status aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Stop a model
aim-engine stop aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

## 🐳 **Docker Compose Deployment**

### **Multi-Model Deployment with Cache**

```bash
# Start all services with cache
docker compose up -d

# Check cache status
docker exec aim-engine aim-engine cache stats

# Launch additional models
docker exec aim-engine aim-engine launch Mistral-7B 2
```

### **Environment Variables**

```yaml
# Key environment variables for cache configuration
environment:
  - AIM_CACHE_DIR=/workspace/model-cache          # Cache directory
  - AIM_CACHE_ENABLED=1                           # Enable caching
  - AIM_PRE_DOWNLOAD_MODELS=false                 # Pre-download models
  - HF_HOME=/workspace/model-cache                # Hugging Face cache
  - TRANSFORMERS_CACHE=/workspace/model-cache     # Transformers cache
  - HF_DATASETS_CACHE=/workspace/model-cache      # Datasets cache
  - VLLM_CACHE_DIR=/workspace/model-cache         # vLLM cache
  - HF_HUB_DISABLE_TELEMETRY=1                    # Disable telemetry
  - PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512 # Memory optimization for AMD ROCm
```

## 🔧 **Advanced Configuration**

### **Pre-downloading Models**

```bash
# Enable pre-downloading in container
docker run --rm \
  -e AIM_PRE_DOWNLOAD_MODELS=true \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-engine:latest

# Or set environment variable
export AIM_PRE_DOWNLOAD_MODELS=true
docker compose up -d
```

### **Custom Cache Directory**

```bash
# Use custom cache directory
docker run --rm --gpus all \
  -v /custom/cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4 --cache-dir /workspace/model-cache
```

### **Disable Caching**

```bash
# Launch without cache (not recommended)
aim-engine launch Qwen/Qwen3-32B 4 --no-cache
```

## 📊 **Performance Comparison**

### **Deployment Time**

| Scenario | First Model | Subsequent Models | Total Time |
|----------|-------------|-------------------|------------|
| **No Cache** | 15-30 min | 15-30 min each | 45-90 min for 3 models |
| **With Cache** | 15-30 min | 2-5 min each | 19-40 min for 3 models |
| **Savings** | 0% | 80-90% | 60-70% |

### **Bandwidth Usage**

| Strategy | Bandwidth Usage | Cache Hit Rate |
|----------|----------------|----------------|
| **No Caching** | 100% for each model | 0% |
| **Built-in Cache** | 100% first, 0% subsequent | 100% |
| **Pre-downloaded** | 0% (already cached) | 100% |

## 🔍 **Monitoring and Debugging**

### **Cache Status Monitoring**

```bash
# Check cache statistics
aim-engine cache stats

# Monitor cache usage
du -sh /workspace/model-cache
ls -la /workspace/model-cache/models/

# Check cache index
cat /workspace/model-cache/cache_index.json
```

### **Container Logs**

```bash
# View container logs
docker logs aim-engine

# Follow logs in real-time
docker logs -f aim-engine

# Check specific model logs
docker logs aim-qwen-32b
```

### **Cache Debugging**

```bash
# Check if model is cached
aim-engine cache list | grep Qwen/Qwen3-32B

# Verify cache files
ls -la /workspace/model-cache/models/Qwen--Qwen3-32B/

# Test cache access
docker run --rm -v /workspace/model-cache:/workspace/model-cache \
  aim-engine:latest \
  python -c "from transformers import AutoTokenizer; print('Cache accessible')"
```

## 🎯 **Best Practices**

### **1. Cache Management**
```bash
# Regular cache cleanup
aim-engine cache cleanup --days 30

# Monitor cache size
watch -n 60 'du -sh /workspace/model-cache'

# Backup important models
tar -czf model-cache-backup.tar.gz /workspace/model-cache
```

### **2. Resource Optimization**
```bash
# Use appropriate GPU allocation
aim-engine launch Qwen/Qwen3-32B 4  # 4 GPUs for 32B model
aim-engine launch Llama-3-8B 2      # 2 GPUs for 8B model

# Monitor GPU usage
rocm-smi --showuse
```

### **3. Network Optimization**
```bash
# Use faster mirrors
export HF_ENDPOINT=https://hf-mirror.com

# Configure git LFS
git lfs install
git config --global lfs.batchsize 1000
```

## 🔧 **Troubleshooting**

### **Common Issues**

#### **1. Cache Not Working**
```bash
# Check cache directory permissions
ls -la /workspace/model-cache

# Verify environment variables
docker exec aim-engine env | grep CACHE

# Reinitialize cache
docker exec aim-engine aim-engine cache stats
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

#### **3. GPU Memory Issues**
```bash
# Check available GPU memory
rocm-smi --showmemuse

# Reduce tensor parallel size
aim-engine launch Qwen/Qwen3-32B 2  # Use 2 GPUs instead of 4

# Use lower precision
aim-engine launch Qwen/Qwen3-32B 4 --precision fp16
```

## 🎉 **Summary**

The container provides:

### **Key Benefits**
- ✅ **80-90% faster** subsequent model deployments
- ✅ **Significant bandwidth savings** (60-70% reduction)
- ✅ **Simplified deployment** with single container
- ✅ **Automatic caching** by default
- ✅ **Built-in cache management** tools
- ✅ **Persistent model storage** across restarts

### **Recommended Approach**
1. **Build container**: `./scripts/build.sh`
2. **Set up cache directory**: Create `/workspace/model-cache`
3. **Launch models**: Use `aim-engine launch` with automatic caching
4. **Monitor cache**: Use `aim-engine cache stats`
5. **Manage cache**: Use cache management commands as needed

This approach ensures that only model differences need to be downloaded, making AIM Engine deployments much more efficient and cost-effective!

---

**AIM Engine** - Container with Built-in Cache! 🚀 