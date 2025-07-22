# AIM Engine

🚀 **AMD Inference Microservice - AI Model Deployment Made Simple**

AIM (AMD Inference Microservice) Engine automatically deploys AI models with optimal configurations and built-in caching for faster subsequent deployments on AMD hardware.

## 🎯 **What AIM Engine Does**

- **🤖 Auto-Detection**: Automatically detects AMD GPUs and selects optimal configurations
- **🚀 Built-in Caching**: Caches models for faster subsequent deployments
- **⚡ Smart Loading**: Only loads recipes for the target model
- **🐳 Single Container**: Everything in one container with vLLM ROCm for AMD
- **🔧 Production Ready**: Health checks, monitoring, and error handling
- **✅ Smart Validation**: Validates vLLM arguments and GPU availability automatically

## 🔧 **Recent Improvements**

### **GPU Count Validation**
- **Container GPU Detection**: Automatically detects available GPUs in the container
- **Smart Adjustment**: Adjusts requested GPU count to match available resources
- **Fallback Handling**: Gracefully handles GPU detection failures

## 🚀 **Quick Start**

### **Combined AIM Engine + vLLM Container**

This approach uses a single container that includes both AIM Engine's intelligent recipe selection tools and the vLLM ROCm runtime for maximum efficiency and simplicity.

#### **1. Build the Combined Container**
```bash
# Clone the repository
git clone https://github.com/Yu-amd/aim-engine.git
cd aim-engine

# Build the combined container
./build-aim-vllm.sh
```

#### **2. Generate Optimal Configuration**
```bash
# Generate optimal vLLM command
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B
```

#### **3. Run vLLM Server Directly**
```bash
# Start vLLM server with optimal configuration
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B
```

#### **4. Test the Endpoint**
```bash
# Test basic connectivity
curl -X GET http://localhost:8000/health

# Test model info
curl -X GET http://localhost:8000/v1/models

# Test completion endpoint
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "prompt": "Hello, how are you?",
    "max_tokens": 50,
    "temperature": 0.7
  }'

# Test chat completion
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

#### **5. Monitor Performance and Metrics**
```bash
# Check container status
docker ps

# Monitor container logs
docker logs -f <container_name>

# Monitor resource usage
docker stats <container_name>

# Check GPU utilization
docker exec <container_name> rocm-smi

# Monitor memory usage
docker exec <container_name> free -h

# Check API metrics (if available)
curl -X GET http://localhost:8000/metrics

# Test throughput with multiple requests
for i in {1..5}; do
  curl -X POST http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "Qwen/Qwen3-32B",
      "prompt": "Test request '$i'",
      "max_tokens": 20,
      "temperature": 0.1
    }' &
done
wait
```

## 📋 **How to Use AIM Engine**

### **Combined Container Commands**

The combined container provides three main commands for different use cases:

#### **1. Configuration Generation (`aim-generate`)**
```bash
# Generate optimal vLLM command
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B

# Specify custom parameters
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B --gpu-count 4 --precision fp16 --port 8001
```

#### **2. Direct Server Launch (`aim-serve`)**
```bash
# Launch server with optimal configuration
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B

# Launch with custom parameters
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8001:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B --gpu-count 4 --precision fp16
```

#### **3. Interactive Development (`aim-shell`)**
```bash
# Interactive shell for development
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell

# Inside the container, you can run:
# python3 generate_docker_command.py Qwen/Qwen3-32B
# python3 -m vllm.entrypoints.openai.api_server --help
# python3 -c "from aim_recipe_selector import AIMRecipeSelector; print('Loaded!')"
```

#### **Benefits of Combined Container**
- ✅ **Single Container**: No Docker-in-Docker complexity
- ✅ **Shared Environment**: AIM Engine tools and vLLM runtime together
- ✅ **Direct Execution**: Run vLLM commands directly within container
- ✅ **Simplified Deployment**: One container handles everything
- ✅ **Better Resource Management**: No container orchestration overhead

### **Cache Management**

The combined container automatically manages model caching. Cache is shared across all container instances.

```bash
# Check cache status (from inside container)
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  python3 -c "
from aim_cache_manager import AIMCacheManager
cache = AIMCacheManager('/workspace/model-cache')
stats = cache.get_cache_stats()
print(f'Cached models: {stats[\"total_models\"]}')
print(f'Total size: {stats[\"total_size_gb\"]:.2f} GB')
"
```

### **Model Management**

```bash
# List running containers
docker ps | grep aim-vllm

# Check container logs
docker logs <container_name>

# Stop a model
docker stop <container_name>

# Monitor resource usage
docker stats <container_name>
```

## 📊 **Performance Benefits**

### **Deployment Speed**
|    Scenario    | First Model | Subsequent Models |   Total Time  |
|----------------|-------------|-------------------|---------------|
| **No Cache**   | 15-30 min   | 15-30 min each    | 45-90 min     |
| **With Cache** | 15-30 min   | 2-5 min each      | **19-40 min** |

### **Bandwidth Savings**
- **First model**: Downloads everything (100% bandwidth)
- **Subsequent models**: Only downloads differences (0-20% bandwidth)
- **Cache hit rate**: 100% for shared components

## 🔧 **Configuration Options**

### **Environment Variables**
```bash
# Cache configuration
AIM_CACHE_DIR=/workspace/model-cache
AIM_CACHE_ENABLED=1
HF_HOME=/workspace/model-cache
TRANSFORMERS_CACHE=/workspace/model-cache
VLLM_CACHE_DIR=/workspace/model-cache

# Performance optimization
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
HF_HUB_DISABLE_TELEMETRY=1
```

### **Custom Cache Directory**
```bash
# Use custom cache location
docker run --rm --gpus all \
  -v /custom/cache:/workspace/model-cache \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4
```

## 🛠️ **Development**

### **Building from Source**
```bash
# Build container
docker build -t aim-engine:latest .

# Or use build script
./scripts/build.sh
```

### **Running Tests**
```bash
# Run all tests
python -m pytest tests/

# Run specific test
python tests/test_aim_implementation.py
```

### **Project Structure**
```
aim-engine/
├── aim_recipe_selector.py      # Intelligent recipe selection
├── aim_config_generator.py     # Configuration generation
├── aim_cache_manager.py        # Model caching system
├── Dockerfile.aim-vllm         # Combined container Dockerfile
├── build-aim-vllm.sh           # Build script for combined container
├── AIM_VLLM_USAGE.md           # Combined container usage guide
├── AIM_ENGINE_DESIGN_SUMMARY.md # Technical architecture summary
├── models/                     # Model definitions
├── recipes/                    # AIM recipes
├── templates/                  # Configuration templates
├── tests/                      # Test files
├── docs/                       # Documentation
└── requirements.txt            # Python dependencies
```

## 🧹 **Cleanup and Maintenance**

### **Container Cleanup**

#### **Stop and Remove All Containers**
```bash
# Stop all running containers (safe - won't error if none running)
docker stop $(docker ps -q) 2>/dev/null || true

# Remove all containers (including stopped ones) (safe - won't error if none exist)
docker rm $(docker ps -aq) 2>/dev/null || true

# Or do both in one command
docker stop $(docker ps -q) 2>/dev/null || true && docker rm $(docker ps -aq) 2>/dev/null || true
```

#### **Clean Up Specific Containers**
```bash
# List all containers
docker ps -a

# Stop specific container
docker stop <container-name>

# Remove specific container
docker rm <container-name>

# Force remove (if container is running)
docker rm -f <container-name>
```

#### **Clean Up Images**
```bash
# Remove unused images
docker image prune

# Remove all unused images (including untagged)
docker image prune -a

# Remove specific image
docker rmi <image-name>
```

### **Port Cleanup**

#### **Check Port Usage**
```bash
# Check what's using a specific port
netstat -tlnp | grep :8000

# Check all listening ports
netstat -tlnp

# Alternative using ss command
ss -tlnp | grep :8000
```

#### **Kill Process Using Port**
```bash
# Find process using port 8000
lsof -i :8000

# Kill process by PID
kill -9 <PID>

# Or kill all processes using the port
sudo fuser -k 8000/tcp
```

### **Cache Cleanup**

#### **Model Cache Management**
```bash
# Check cache size
du -sh /workspace/model-cache

# List cached models
ls -la /workspace/model-cache/models/

# Remove specific model from cache
rm -rf /workspace/model-cache/models/<model-name>

# Clean up old cache files
find /workspace/model-cache -type f -mtime +30 -delete
```

### **Complete System Cleanup**

#### **Full Cleanup Script**
```bash
#!/bin/bash
echo "🧹 Starting complete cleanup..."

# Stop and remove all containers
echo "📦 Stopping and removing containers..."
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Remove unused images
echo "🖼️  Removing unused images..."
docker image prune -f

# Remove unused volumes
echo "💾 Removing unused volumes..."
docker volume prune -f

# Remove unused networks
echo "🌐 Removing unused networks..."
docker network prune -f

# Clean up cache (optional - uncomment if needed)
# echo "🗂️  Cleaning up model cache..."
# rm -rf /workspace/model-cache/*

echo "✅ Cleanup complete!"
```

#### **Quick Cleanup Commands**
```bash
# One-liner cleanup
docker system prune -f

# Cleanup everything (including images)
docker system prune -a -f

# Cleanup with volumes
docker system prune -a -f --volumes
```

## 🔍 **Troubleshooting**

### **Combined Container Issues**

#### **Container Build Failures**
```bash
# Check if build script is executable
chmod +x build-aim-vllm.sh

# Build manually with verbose output
docker build -f Dockerfile.aim-vllm -t aim-vllm:latest . --progress=plain

# Check for missing dependencies
docker run --rm aim-vllm:latest python3 -c "import aim_recipe_selector; print('AIM Engine loaded successfully')"
```

#### **Port Already in Use**
```bash
# Check if port is in use
netstat -tlnp | grep :8000 || ss -tlnp | grep :8000 || echo "No process found on port 8000"

# Use a different port
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B --port 8001
```

#### **GPU Memory Issues**
```bash
# Check GPU memory usage
rocm-smi

# Check container GPU access
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  aim-vllm:latest \
  rocm-smi

# Reduce GPU memory utilization
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B --gpu-count 1
```

#### **Container Startup Failures**
```bash
# Check if containers are running
docker ps | grep aim-vllm

# Clean up all containers (safe - won't error if none exist)
docker stop $(docker ps -q) 2>/dev/null || true && docker rm $(docker ps -aq) 2>/dev/null || true

# Try again with the combined container
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B
```

### **General Issues**

#### **GPU Detection Issues**
```bash
# Check GPU availability
rocm-smi --showproductname

# Check PyTorch GPU detection inside container
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  aim-vllm:latest \
  python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}')"

# Check environment variables
docker run --rm -it aim-vllm:latest env | grep -E "(HIP|CUDA|VLLM)"
```

#### **Model Download Issues**
```bash
# Check cache directory
ls -la /workspace/model-cache/

# Check network connectivity
docker run --rm aim-vllm:latest curl -I https://huggingface.co

# Clear cache and retry
rm -rf /workspace/model-cache/*
```

#### **Command Execution Issues**
```bash
# Test aim-generate command
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate --help

# Test aim-serve command
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-serve --help
```

## 📚 **Documentation**

- **[Combined Container Usage](AIM_VLLM_USAGE.md)** - Complete guide for the combined container approach
- **[Design Summary](AIM_ENGINE_DESIGN_SUMMARY.md)** - Technical architecture and recipe selection mechanism
- **[Complete Guide](docs/README.md)** - Comprehensive documentation
- **[Installation Guide](docs/guides/installation.md)** - Setup instructions
