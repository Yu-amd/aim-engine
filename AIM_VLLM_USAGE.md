# AIM Engine based on vLLM ROCm container - Usage Guide

## 🎯 **Overview**

This guide shows how to use the AIM Engine with the vLLM ROCm container, which includes both the intelligent recipe selection tools and the vLLM inference runtime in a single container.

## 🏗️ **Architecture Benefits**

### **✅ Single Container Solution**
- **No Docker-in-Docker**: Eliminates the complexity of nested containers
- **Shared Environment**: AIM Engine tools and vLLM runtime share the same environment
- **Simplified Deployment**: One container handles both configuration and inference
- **Better Resource Management**: No overhead from container orchestration

### **✅ Direct Command Execution**
- **Configuration Generation**: Run `aim-generate` to get optimal vLLM commands
- **Direct vLLM Execution**: Run `aim-serve` to start vLLM server directly
- **Interactive Development**: Use `aim-shell` for interactive exploration
- **Custom Scripts**: Execute any Python code with AIM Engine tools

## 🚀 **Quick Start**

### **1. Build the Combined Container**
```bash
# Build the container
./build-aim-vllm.sh

# Or manually
docker build -f Dockerfile.aim-vllm -t aim-vllm:latest .
```

### **2. Generate Optimal Configuration**
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

**Output Example:**
```bash
# AIM Engine Recipe: qwen3-32b-mi300x-bf16
# Model: Qwen/Qwen3-32B
# GPUs: 1 (from 10 available)
# Precision: bf16
# Backend: vllm
# Port: 8000

python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen3-32B --dtype bfloat16 --max-num-batched-tokens 8192 --max-model-len 32768 --gpu-memory-utilization 0.9 --trust-remote-code --port 8000
```

### **3. Run vLLM Server Directly**
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

## 📋 **Usage Patterns**

### **Pattern 1: Configuration Generation Only**
```bash
# Generate and save configuration for later use
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B --port 8001 > vllm-command.txt
```

### **Pattern 2: Direct Server Launch**
```bash
# Launch server and keep it running
docker run --rm -d \
  --name vllm-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B
```

### **Pattern 3: Interactive Development**
```bash
# Interactive shell for development and testing
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

### **Pattern 4: Custom Python Scripts**
```bash
# Run custom Python code with AIM Engine tools
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  python3 -c "
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
config = selector.get_optimal_configuration('Qwen/Qwen3-32B')
print(f'Optimal config: {config}')
"
```

## 🔧 **Advanced Usage**

### **Custom GPU Count and Precision**
```bash
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

### **Multiple Models**
```bash
# Launch multiple models on different ports
docker run --rm -d \
  --name vllm-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B

docker run --rm -d \
  --name vllm-llama-7b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8001:8000 \
  aim-vllm:latest \
  aim-serve meta-llama/Llama-2-7b-chat-hf
```

### **Development and Testing**
```bash
# Mount source code for development
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -v $(pwd):/workspace/aim-engine \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell
```

## 📊 **Monitoring and Management**

### **Check Running Containers**
```bash
# List running vLLM containers
docker ps | grep aim-vllm

# Check container logs
docker logs vllm-qwen-32b

# Monitor resource usage
docker stats vllm-qwen-32b
```

### **Test API Endpoints**
```bash
# Test model info
curl -X GET http://localhost:8000/v1/models

# Test completion
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "prompt": "Hello, how are you?",
    "max_tokens": 50,
    "temperature": 0.7
  }'
```

## 🎯 **Benefits Over Traditional Approach**

### **✅ Simplified Workflow**
- **Before**: Generate command → Copy → Run in separate container
- **After**: Single command execution within container

### **✅ Better Resource Utilization**
- **Before**: Two containers (AIM Engine + vLLM)
- **After**: Single container with both capabilities

### **✅ Improved Development Experience**
- **Before**: Complex Docker-in-Docker setup
- **After**: Direct access to both tools and runtime

### **✅ Consistent Environment**
- **Before**: Environment differences between containers
- **After**: Shared environment for all operations

## 🔄 **Migration from Traditional Approach**

### **Old Workflow:**
```bash
# 1. Generate command
python3 generate_docker_command.py Qwen/Qwen3-32B

# 2. Copy and run in separate container
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  rocm/vllm:latest \
  [generated_command]
```

### **New Workflow:**
```bash
# Single command execution
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

This combined approach provides a much cleaner and more efficient way to use AIM Engine with vLLM! 🚀 
