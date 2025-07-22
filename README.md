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

### **1. Build the Container**
```bash
# Clone and build
git clone https://github.com/Yu-amd/aim-engine.git
cd aim-engine
./scripts/build.sh
```

### **2. Launch Your First Model**
```bash
# Launch with auto-detection (recommended)
docker run --rm --gpus all \
  -v /workspace/model-cache:/workspace/model-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B
```

### **3. Launch Another Model (Uses Cache)**
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

### **Basic Commands**

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
AIM-implementation/
├── aim_*.py                    # Core AIM Engine modules
├── models/                     # Model definitions
├── recipes/                    # AIM recipes
├── templates/                  # Configuration templates
├── tests/                      # Test files
├── scripts/                    # Build scripts
├── docs/                       # Documentation
├── Dockerfile                  # Container (with built-in cache)
└── requirements.txt            # Python dependencies
```

## 🔍 **Troubleshooting**

### **Common Issues**

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
