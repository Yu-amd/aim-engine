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

### **Option 1: Direct vLLM with AIM Engine Recipe Selection (Recommended)**

This approach uses AIM Engine's intelligent recipe selection to generate optimal Docker commands, then runs vLLM directly for maximum reliability.

#### **1. Generate Optimal Docker Command**
```bash
# Clone the repository
git clone https://github.com/Yu-amd/aim-engine.git
cd aim-engine

# Generate optimal Docker command for any model
python3 generate_docker_command.py Qwen/Qwen3-32B
```

#### **2. Run the Generated Command**
```bash
# Copy and paste the generated command
docker run --rm \
  --name vllm-qwen-qwen3-32b-1gpu-bf16 \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  rocm/vllm:latest \
  python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen3-32B --dtype bfloat16 --max-num-batched-tokens 8192 --max-model-len 32768 --gpu-memory-utilization 0.9 --trust-remote-code --port 8000
```

#### **3. Test the Endpoint**
```bash
# Test the API
curl -X GET http://localhost:8000/v1/models

# Test chat completion
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-32B", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}'
```

### **Option 2: Traditional AIM Engine Container**

#### **1. Build the Container**
```bash
# Clone and build
git clone https://github.com/Yu-amd/aim-engine.git
cd aim-engine
./scripts/build.sh
```

#### **2. Launch Your First Model**
```bash
# Launch with auto-detection (recommended)
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B
```

#### **3. Launch Another Model (Uses Cache)**
```bash
# This will be much faster - uses cached components
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8001:8000 \
  aim-engine:latest \
  aim-engine launch Llama-3-8B
```

## 📋 **How to Use AIM Engine**

### **Recipe Selection Script (Recommended)**

The `generate_docker_command.py` script uses AIM Engine's intelligent recipe selection to generate optimal Docker commands for any model.

#### **Basic Usage**
```bash
# Generate optimal command for any model
python3 generate_docker_command.py Qwen/Qwen3-32B

# Specify GPU count
python3 generate_docker_command.py Qwen/Qwen3-32B 4

# Specify precision
python3 generate_docker_command.py Qwen/Qwen3-32B 4 bf16

# Specify custom port
python3 generate_docker_command.py Qwen/Qwen3-32B 4 bf16 8001
```

#### **Benefits of Recipe Selection**
- ✅ **Automatic GPU detection** and optimal allocation
- ✅ **Smart precision selection** (bf16, fp16, fp8, etc.)
- ✅ **Performance-tuned parameters** from tested recipes
- ✅ **AMD/ROCm optimized** device mounts and settings
- ✅ **Model-specific optimizations** based on size and requirements
- ✅ **Reliable vLLM deployment** with direct Docker commands

### **Traditional AIM Engine Commands**

```bash
# Launch model with auto-detection
aim-engine launch Qwen/Qwen3-32B

# Launch with specific GPU count
aim-engine launch Qwen/Qwen3-32B 4

# Launch with specific precision
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# Serve model directly (bypasses orchestration)
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4
```

### **Cache Management**

```bash
# Check cache status
aim-engine cache stats

# List cached models
aim-engine cache list

# Clean up old models
aim-engine cache cleanup --days 30
```

### **Model Management**

```bash
# List running models
aim-engine list

# Get model status
aim-engine status <container-name>

# Stop a model
aim-engine stop <container-name>
```

## 🐳 **Docker Usage**

### **Single Model Deployment**
```bash
# Basic deployment
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4
```

### **Multiple Models with Docker Compose**
```bash
# Start all services
docker compose up -d

# Check cache status
docker exec aim-engine aim-engine cache stats

# Launch additional models
docker exec aim-engine aim-engine launch Mistral-7B 2
```

### **Interactive Mode**
```bash
# Run container interactively
docker run -it --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aim-engine:latest
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
├── aim_*.py                    # Core AIM Engine modules
├── generate_docker_command.py  # Recipe selection script (recommended)
├── models/                     # Model definitions
├── recipes/                    # AIM recipes
├── templates/                  # Configuration templates
├── tests/                      # Test files
├── scripts/                    # Build scripts
├── docs/                       # Documentation
├── Dockerfile                  # Container (with built-in cache)
└── requirements.txt            # Python dependencies
```

## 🧹 **Cleanup and Maintenance**

### **Container Cleanup**

#### **Stop and Remove All Containers**
```bash
# Stop all running containers
docker stop $(docker ps -q)

# Remove all containers (including stopped ones)
docker rm $(docker ps -aq)

# Or do both in one command
docker stop $(docker ps -q) && docker rm $(docker ps -aq)
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

### **Recipe Selection Script Issues**

#### **Port Already in Use**
```bash
# Check what's using the port
netstat -tlnp | grep :8000

# Use a different port
python3 generate_docker_command.py Qwen/Qwen3-32B 1 bf16 8001
```

#### **GPU Memory Issues**
```bash
# Check available GPU memory
rocm-smi

# Reduce GPU count
python3 generate_docker_command.py Qwen/Qwen3-32B 2

# Use lower precision
python3 generate_docker_command.py Qwen/Qwen3-32B 4 fp16
```

#### **Container Startup Failures**
```bash
# Check if containers are running
docker ps

# Clean up all containers
docker stop $(docker ps -q) && docker rm $(docker ps -aq)

# Try again with the generated command
```

### **Traditional AIM Engine Issues**

#### **Cache Not Working**
```bash
# Check cache directory permissions
ls -la /workspace/model-cache

# Verify environment variables
docker exec aim-engine env | grep CACHE

# Reinitialize cache
docker exec aim-engine aim-engine cache stats
```

#### **GPU Memory Issues**
```bash
# Check available GPU memory
rocm-smi

# Reduce GPU count
aim-engine launch Qwen/Qwen3-32B 2  # Use 2 GPUs instead of 4

# Use lower precision
aim-engine launch Qwen/Qwen3-32B 4 --precision fp16
```

#### **Model Download Failures**
```bash
# Check network connectivity
curl -I https://huggingface.co/Qwen/Qwen3-32B

# Use alternative mirror
export HF_ENDPOINT=https://hf-mirror.com
```

## 📚 **Documentation**

- **[Complete Guide](docs/README.md)** - Comprehensive documentation
- **[Container Guide](docs/guides/unified-container-cache.md)** - Using the container
- **[User Guide](docs/guides/user-guide.md)** - How to use AIM Engine
- **[Installation Guide](docs/guides/installation.md)** - Setup instructions
