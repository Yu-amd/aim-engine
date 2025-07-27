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

# Use the generated command to deploy
docker run --rm -d \
  --name aim-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  rocm/vllm:latest \
  python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-32B --dtype bfloat16 --max-num-batched-tokens 8192 --max-model-len 32768 --gpu-memory-utilization 0.9 --trust-remote-code --port 8000
```

## **How to Use AIM Engine**

### **1. Auto-Detection Mode (Recommended)**
```bash
# Just specify the model - everything else is automatic
aim-generate Qwen/Qwen3-32B
```

**What happens:**
1. Detects available GPUs (e.g., 4 GPUs)
2. Auto-selects optimal GPU count (32B → 4 GPUs)
3. Auto-selects optimal precision (32B → bf16)
4. Loads only Qwen/Qwen3-32B recipes
5. Selects best matching recipe
6. Deploys with optimal configuration

### **2. Customer Specified Configuration**
```bash
# Override auto-selection with specific parameters
aim-generate Qwen/Qwen3-32B 4 --precision bf16
```

**What happens:**
1. Uses customer specified GPU count (4 GPUs)
2. Uses customer specified precision (bf16)
3. Loads only Qwen/Qwen3-32B recipes
4. Selects best matching recipe for 4 GPUs + bf16
5. Deploys with customer configuration

### **3. Unified Container Benefits**

- **Single Container**: No Docker-in-Docker complexity
- **Shared Environment**: AIM Engine tools and vLLM runtime together
- **Direct Execution**: Run vLLM commands directly within container
- **Simplified Deployment**: One container handles everything
- **Better Resource Management**: No container orchestration overhead

## **Performance Benefits**

### **Memory Efficiency**
- **Before**: Loads all recipes (could be hundreds)
- **After**: Loads only model-specific recipes (typically 1-5)

### **Startup Time**
- **Before**: ~100-500ms to load all recipes
- **After**: ~10-50ms to load model-specific recipes

### **Scalability**
- **Before**: Performance degrades with recipe count
- **After**: Consistent performance regardless of total recipe count

## **Configuration Options**

### **GPU Count Selection Priority**
1. **Customer specified** (if within available GPUs)
2. **Model size heuristic**:
   - 7B/8B models: 1 GPU
   - 13B/14B models: 2 GPUs
   - 32B/34B models: 4 GPUs
   - 70B/72B models: 8 GPUs
3. **Maximum available** (if heuristic exceeds available)

### **Precision Selection Priority**
1. **Customer specified**
2. **Model size heuristic**:
   - 7B/8B models: fp16 (faster, sufficient accuracy)
   - 13B+ models: bf16 (better numerical stability)
3. **Fallback alternatives** (if primary choice fails)

## **Development**

### **Project Structure**
```
aim-engine/
├── src/aim_engine/        # Core Python package
├── config/                # Configuration files
│   ├── models/           # Model definitions
│   ├── recipes/          # AIM recipes
│   └── templates/        # Configuration templates
├── scripts/               # Build and deployment scripts
├── docker/                # Docker-related files
├── docs/                  # Documentation
├── k8s/                   # Kubernetes deployment
├── examples/              # Usage examples
└── tests/                 # Test files
```

### **Running Tests**
```bash
# Run all tests
python -m pytest tests/

# Run specific test
python tests/test_aim_implementation.py

# Run with coverage
python -m pytest tests/ --cov=.
```

### **Building Containers**
```bash
# Build standard container
./scripts/build-aim-vllm.sh

# Build TGI container for development
docker build -f docker/Dockerfile.aim-tgi -t aim-tgi:latest .
```

### **Cleanup Script**
```bash
#!/bin/bash
# Cleanup script for development

echo "Cleaning up Docker resources..."

# Stop and remove containers
docker stop $(docker ps -q --filter "ancestor=aim-vllm:latest") 2>/dev/null || true
docker rm $(docker ps -aq --filter "ancestor=aim-vllm:latest") 2>/dev/null || true

# Remove images
echo "Removing unused images..."
docker rmi aim-vllm:latest 2>/dev/null || true
docker rmi aim-tgi:latest 2>/dev/null || true

# Clean up dangling images
docker image prune -f

# Clean up build cache
docker builder prune -f

# Optional: Clean up model cache
# echo "Cleaning up model cache..."
# rm -rf /workspace/model-cache/*

echo "Cleanup complete!"
```

## **Troubleshooting**

### **Common Issues**

#### **1. GPU Not Detected**
```bash
# Check GPU availability
rocm-smi

# Check Docker GPU access
docker run --rm --device=/dev/kfd rocm/vllm:latest rocm-smi
```

#### **2. Memory Issues**
```bash
# Check available memory
free -h

# Reduce GPU memory utilization
aim-generate Qwen/Qwen3-32B --gpu-memory-utilization 0.7
```

#### **3. Model Download Issues**
```bash
# Check network connectivity
curl -I https://huggingface.co/Qwen/Qwen3-32B

# Use local model cache
docker run -v /path/to/models:/workspace/model-cache aim-vllm:latest
```

#### **4. Port Conflicts**
```bash
# Check port usage
netstat -tlnp | grep 8000

# Use different port
docker run -p 8001:8000 aim-vllm:latest
```

### **Debug Mode**
```bash
# Enable debug logging
export VLLM_LOGGING_LEVEL=DEBUG

# Run with verbose output
aim-generate Qwen/Qwen3-32B --verbose
```

### **Health Checks**
```bash
# Check container health
docker ps | grep aim-engine

# Check logs
docker logs <container-name>

# Check endpoint
curl http://localhost:8000/health
```

### **Performance Monitoring**
```bash
# Monitor resource usage
docker stats

# Check GPU utilization
rocm-smi

# Monitor model performance
curl http://localhost:8000/metrics
```

### **Complete Diagnostic Script**
```bash
#!/bin/bash
echo "=== AIM Engine Diagnostic Report ==="
echo "Date: $(date)"
echo ""

echo "=== System Information ==="
uname -a
echo ""

echo "=== Docker Information ==="
docker version
docker ps -a
echo ""

echo "=== GPU Information ==="
rocm-smi 2>/dev/null || echo "ROCm not available"
echo ""

echo "=== Memory Information ==="
free -h
echo ""

echo "=== Disk Space ==="
df -h
echo ""

echo "=== Network Information ==="
ip addr show | grep inet
echo ""

echo "=== AIM Engine Status ==="
docker ps | grep aim-engine || echo "No AIM Engine containers running"
echo ""

echo "=== Model Cache Status ==="
ls -la /workspace/model-cache 2>/dev/null || echo "Model cache not found"
echo ""

echo "=== Recent Logs ==="
docker logs --tail 20 $(docker ps -q --filter "ancestor=aim-vllm:latest") 2>/dev/null || echo "No AIM Engine logs found"
echo ""

echo "=== Diagnostic Complete ==="
```

## **Documentation**

- **Architecture**: See `docs/ARCHITECTURE.md`
- **API Reference**: See `docs/API.md`
- **Recipe System**: See `docs/RECIPE_GUIDE.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Docker Deployment**: See `docker/docs/`
- **Kubernetes Deployment**: See `k8s/docs/`

## **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## **Support**

- **Issues**: [GitHub Issues](https://github.com/Yu-amd/aim-engine/issues)
- **Documentation**: [Project Wiki](https://github.com/Yu-amd/aim-engine/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/Yu-amd/aim-engine/discussions)
