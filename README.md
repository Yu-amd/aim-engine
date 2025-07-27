# AIM Engine

**AMD Inference Microservice - AI Model Deployment Made Simple**

AIM (AMD Inference Microservice) Engine automatically deploys AI models with optimal configurations and built-in caching for faster subsequent deployments on AMD hardware.

## **What AIM Engine Does**

- **Auto-Detection**: Automatically detects AMD GPUs and selects optimal configurations
- **Built-in Caching**: Caches models for faster subsequent deployments
- **Smart Loading**: Only loads recipes for the target model
- **Single Container**: Everything in one container with vLLM ROCm for AMD
- **Production Ready**: Health checks, monitoring, and error handling
- **Smart Validation**: Validates vLLM arguments and GPU availability automatically

## **Recent Improvements**

- **Optimized Recipe Loading**: Only loads recipes for the specific model (10-50ms vs 100-500ms)
- **Memory Efficiency**: Reduced memory footprint by loading only relevant recipes
- **Faster Startup**: Consistent performance regardless of total recipe count
- **Better Scalability**: Performance doesn't degrade with more models

## **Quick Start**

### **Prerequisites**
- AMD GPU with ROCm support (MI300X, MI325X, etc.)
- Docker installed and running
- At least 16GB RAM (32GB+ recommended for large models)

### **Installation**
```bash
# Clone the repository
git clone <repository-url>
cd aim-engine

# Build the Docker image
./scripts/build-aim-vllm.sh
```

### **Basic Usage**
```bash
# Launch model with auto-detection
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B

# Start interactive shell
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell
```

### **Testing Your Endpoint**
Once your AIM Engine is running, verify it's ready for inference:

```bash
# Test if the endpoint is responding
curl -f http://localhost:8000/health

# Test if models are loaded and ready
curl -f http://localhost:8000/v1/models

# Test a simple inference request
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

**Expected responses:**
- **Health endpoint**: Returns HTTP 200 (empty response)
- **Models endpoint**: Returns JSON with available models
- **Chat endpoint**: Returns JSON with generated text

If all tests pass, your AIM Engine is ready for use with agent examples and other applications!

### **Production Deployment**
```bash
# Generate deployment command
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B
```

## **Kubernetes Deployment**

### **Quick Setup (Complete Cluster)**
```bash
# Set up complete Kubernetes cluster with AMD GPU support
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

### **Deploy to Existing Cluster**
```bash
# Deploy with default settings
sudo ./k8s/scripts/deploy-aim-engine.sh

# Deploy with custom model
sudo ./k8s/scripts/deploy-aim-engine.sh --model Qwen/Qwen3-32B --memory-limit 80Gi

# Deploy with multiple GPUs
sudo ./k8s/scripts/deploy-aim-engine.sh --gpu-count 2 --memory-limit 64Gi
```

## **Examples**

### **Running Examples**
```bash
cd examples

# Use the quick start script (recommended)
./quick_start.sh

# Or run individual examples
python3 simple_agent.py      # Basic chat agent
python3 advanced_agent.py    # Agent with tools
python3 web_agent.py         # Web interface
```

### **Available Examples**
- **Simple Agent**: Basic conversational agent with streaming responses
- **Advanced Agent**: Agent with tools, memory, and structured reasoning
- **Web Agent**: Modern web interface with real-time chat
- **Test Scripts**: Various testing and diagnostic tools

See `examples/README.md` for detailed information about each example.

## **Cleanup**

### **Docker Cleanup (Single-Node Deployment)**

#### **Using the Cleanup Script (Recommended)**
```bash
# Basic cleanup (stops and removes containers only)
./scripts/cleanup-docker.sh

# Remove containers and images
./scripts/cleanup-docker.sh --images

# Nuclear option: Remove everything
./scripts/cleanup-docker.sh --all
```

#### **Manual Cleanup Commands**
```bash
# Stop all running AIM Engine containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop

# Remove all AIM Engine containers (any state)
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Remove AIM Engine images
docker rmi aim-vllm:latest --force

# Clean up dangling resources
docker system prune -f
```

### **Kubernetes Cleanup (Cluster Deployment)**

#### **Using the Cleanup Script (Recommended)**
```bash
# Basic cleanup (removes Kubernetes resources only)
sudo ./k8s/scripts/cleanup-kubernetes.sh

# Remove Kubernetes resources and Docker images
sudo ./k8s/scripts/cleanup-kubernetes.sh --images

# Remove everything including local registry
sudo ./k8s/scripts/cleanup-kubernetes.sh --registry

# Nuclear option: Remove entire cluster
sudo ./k8s/scripts/cleanup-kubernetes.sh --cluster

# Complete cleanup (everything)
sudo ./k8s/scripts/cleanup-kubernetes.sh --all
```

#### **Manual Kubernetes Cleanup**
```bash
# Remove AIM Engine deployment
helm uninstall aim-engine -n aim-engine

# Remove namespace
kubectl delete namespace aim-engine

# Remove local registry
docker stop local-registry
docker rm local-registry

# Remove images from registry
docker rmi localhost:5000/aim-vllm:latest
docker rmi aim-vllm:latest
```

### **Quick Cleanup Commands**
```bash
# Docker: Stop and remove all AIM Engine containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop && \
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Kubernetes: Remove AIM Engine resources
kubectl delete all -n aim-engine --all
kubectl delete namespace aim-engine

# Nuclear option: Stop and remove ALL containers (use with caution)
docker ps -q | xargs -r docker stop && docker ps -aq | xargs -r docker rm -f
```

## **Documentation**

- **Architecture**: See `docs/ARCHITECTURE.md`
- **API Reference**: See `docs/API.md`
- **Recipe System**: See `docs/RECIPE_GUIDE.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Docker Deployment**: See `docker/docs/`
- **Kubernetes Deployment**: See `k8s/docs/`
