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

### **Health Checks**

#### **Basic Health Check**
```bash
# Check if container is running
docker ps | grep aim-engine

# Check container logs
docker logs <container-name>

# Test health endpoint
curl http://localhost:8000/health
```

#### **Testing Before Running Agent Examples**
Before running any agent examples in the `examples/` directory, ensure your AIM Engine endpoint is healthy:

```bash
# Quick health check for examples
curl -f http://localhost:8000/health && \
curl -f http://localhost:8000/v1/models && \
echo "✓ AIM Engine is ready for agent examples" || \
echo "✗ AIM Engine needs attention before running examples"
```

**Note**: If you're using a different port (e.g., 8001), replace `8000` with your port number in all the above commands.

## **Agent Examples**

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

## **Documentation**

- **Architecture**: See `docs/ARCHITECTURE.md`
- **API Reference**: See `docs/API.md`
- **Recipe System**: See `docs/RECIPE_GUIDE.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Docker Deployment**: See `docker/docs/`
- **Kubernetes Deployment**: See `k8s/docs/`
