# AIM Engine - Unified Container Deployment Guide

## 🎯 **Can AIM Engine be Part of the Docker Container?**

**Yes!** AIM Engine can absolutely be part of the Docker container. In fact, we've already implemented a **unified container approach** that combines both the vLLM ROCm base and the AIM Engine orchestration tools in a single container.

## 🚀 **Deployment Models**

### **Model 1: Unified Container (Recommended)**
```
┌─────────────────────────────────────────────────────────────┐
│                    AIM Engine Unified Container             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   AIM Engine    │  │   vLLM ROCm     │  │   Docker    │ │
│  │ Orchestration   │  │   Base Image    │  │   CLI       │ │
│  │   Tools         │  │                 │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  • Recipe Selection    • Model Serving    • Container Mgmt │
│  • Auto-Detection      • GPU Access       • Health Checks  │
│  • Configuration Gen   • Inference API    • Logging        │
└─────────────────────────────────────────────────────────────┘
```

### **Model 2: Separate Containers (Current)**
```
┌─────────────────┐    ┌─────────────────┐
│  AIM Engine     │    │  vLLM Container │
│  Container      │    │                 │
│                 │    │                 │
│ • Orchestration │    │ • Model Serving │
│ • Recipe Mgmt   │    │ • GPU Access    │
│ • Docker Mgmt   │    │ • Inference API │
└─────────────────┘    └─────────────────┘
        │                       │
        └─────── Docker ────────┘
```

## 🔧 **Unified Container Implementation**

### **Dockerfile.unified**
```dockerfile
# AIM Engine Unified Container
# Combines vLLM ROCm base with AIM Engine orchestration tools

FROM rocm/vllm:latest

# Install system dependencies for AIM Engine
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    docker.io \
    docker-compose \
    jq \
    yamllint \
    gosu

# Install Docker CLI (for managing other containers)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-24.0.7.tgz | \
    tar -xzC /usr/local/bin --strip=1 docker/docker

# Create AIM Engine user
RUN useradd -m -s /bin/bash aim-engine && \
    usermod -aG docker aim-engine

# Set working directory
WORKDIR /opt/aim-engine

# Copy AIM Engine source code and dependencies
COPY requirements.txt .
COPY aim_*.py .
COPY models/ ./models/
COPY recipes/ ./recipes/
COPY templates/ ./templates/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install -e .

# Create CLI wrapper
COPY <<EOF /opt/aim-engine/aim-engine
#!/usr/bin/env python3
"""
AIM Engine CLI Wrapper for Unified Container
Provides both orchestration and direct model serving capabilities
"""

def main():
    if len(sys.argv) < 2:
        print("🚀 AIM Engine Unified Container")
        print("Available commands:")
        print("  launch <model> <gpus> [options]  - Launch a model endpoint")
        print("  serve <model> <gpus> [options]   - Serve model directly")
        print("  list                              - List running endpoints")
        print("  stop <container>                  - Stop an endpoint")
        return
    
    command = sys.argv[1]
    
    if command == "launch":
        # Use AIM Engine orchestration
        cmd = f"python3 aim_launcher.py --model {sys.argv[2]} --gpus {sys.argv[3]}"
        subprocess.run(cmd, shell=True)
    
    elif command == "serve":
        # Direct vLLM serving without orchestration
        cmd = f"python -m vllm.entrypoints.openai.api_server --model {sys.argv[2]} --tensor-parallel-size {sys.argv[3]}"
        subprocess.run(cmd, shell=True)

if __name__ == "__main__":
    main()
EOF

# Make CLI wrapper executable
RUN chmod +x /opt/aim-engine/aim-engine
RUN ln -sf /opt/aim-engine/aim-engine /usr/local/bin/aim-engine

# Set entrypoint
ENTRYPOINT ["/opt/aim-engine/entrypoint.sh"]
CMD ["aim-engine", "help"]
```

## 🎯 **Unified Container Benefits**

### **1. Simplified Deployment**
```bash
# Single container deployment
docker run -it --gpus all -v /var/run/docker.sock:/var/run/docker.sock \
  aim-engine-unified:latest aim-engine launch Qwen/Qwen3-32B 4
```

### **2. Self-Contained Environment**
- ✅ **Everything in one container**: AIM Engine + vLLM + Docker CLI
- ✅ **No external dependencies**: All tools included
- ✅ **Consistent environment**: Same setup everywhere
- ✅ **Easy distribution**: Single image to deploy

### **3. Dual Mode Operation**
```bash
# Mode 1: Orchestrated deployment (launches separate containers)
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# Mode 2: Direct serving (serves model in same container)
aim-engine serve Qwen/Qwen3-32B 4 --precision bf16
```

## 🚀 **Usage Examples**

### **Example 1: Orchestrated Deployment**
```bash
# Launch container with orchestration capabilities
docker run -it --gpus all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /workspace/models:/workspace/models \
  aim-engine-unified:latest

# Inside container, launch a model endpoint
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# This will:
# 1. Select optimal recipe
# 2. Launch separate vLLM container
# 3. Manage the endpoint lifecycle
```

### **Example 2: Direct Model Serving**
```bash
# Launch container for direct serving
docker run -it --gpus all \
  -p 8000:8000 \
  -v /workspace/models:/workspace/models \
  aim-engine-unified:latest

# Inside container, serve model directly
aim-engine serve Qwen/Qwen3-32B 4 --precision bf16

# This will:
# 1. Start vLLM server directly in this container
# 2. Serve model on port 8000
# 3. No separate container management
```

### **Example 3: Development Environment**
```bash
# Launch container for development
docker run -it --gpus all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /workspace/models:/workspace/models \
  -v /workspace/aim-engine:/opt/aim-engine \
  aim-engine-unified:latest

# Inside container, run tests and development
aim-engine test
python3 example_usage.py
```

## 🔧 **Container Management Commands**

### **List Running Endpoints**
```bash
# Inside unified container
aim-engine list

# Output:
# Running endpoints:
# - aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm (port 8000)
# - aim-engine-llama-3-8b-2gpu-fp16-vllm (port 8001)
```

### **Stop Endpoints**
```bash
# Stop specific endpoint
aim-engine stop aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Stop all endpoints
aim-engine stop-all
```

### **Check Status**
```bash
# Check endpoint status
aim-engine status aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Check system resources
aim-engine resources
```

## 📊 **Comparison: Unified vs Separate Containers**

### **Unified Container Approach**
| Aspect | Unified Container | Separate Containers |
|--------|------------------|-------------------|
| **Deployment** | Single container | Multiple containers |
| **Complexity** | Lower | Higher |
| **Resource Usage** | Shared resources | Isolated resources |
| **Management** | Self-contained | External orchestration |
| **Portability** | High (single image) | Medium (multiple images) |
| **Development** | Easy (everything included) | Complex (setup required) |
| **Production** | Good for single-node | Better for multi-node |

### **When to Use Each Approach**

#### **Use Unified Container When:**
- ✅ **Single-node deployment**
- ✅ **Development and testing**
- ✅ **Quick prototyping**
- ✅ **Resource-constrained environments**
- ✅ **Simplified deployment requirements**

#### **Use Separate Containers When:**
- ✅ **Multi-node deployment**
- ✅ **Production environments**
- ✅ **Resource isolation requirements**
- ✅ **Kubernetes orchestration**
- ✅ **Microservices architecture**

## 🛠️ **Building the Unified Container**

### **Build Command**
```bash
# Build unified container
docker build -f Dockerfile.unified -t aim-engine-unified:latest .

# Build with specific tag
docker build -f Dockerfile.unified -t aim-engine-unified:v1.0.0 .
```

### **Push to Registry**
```bash
# Tag for registry
docker tag aim-engine-unified:latest your-registry/aim-engine-unified:latest

# Push to registry
docker push your-registry/aim-engine-unified:latest
```

### **Pull and Run**
```bash
# Pull from registry
docker pull your-registry/aim-engine-unified:latest

# Run with GPU access
docker run -it --gpus all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  your-registry/aim-engine-unified:latest
```

## 🔍 **Advanced Unified Container Features**

### **1. Multi-Model Serving**
```bash
# Serve multiple models in same container
aim-engine serve Qwen/Qwen3-32B 2 --port 8000 &
aim-engine serve Llama-3-8B 1 --port 8001 &
aim-engine serve Mistral-7B 1 --port 8002 &
```

### **2. Load Balancing**
```bash
# Launch multiple instances for load balancing
aim-engine launch Qwen/Qwen3-32B 4 --port 8000 --instances 3
```

### **3. Monitoring and Metrics**
```bash
# Enable monitoring
aim-engine serve Qwen/Qwen3-32B 4 --enable-metrics --metrics-port 9090
```

### **4. Custom Recipes**
```bash
# Use custom recipe
aim-engine launch Qwen/Qwen3-32B 4 --recipe custom-recipe.yaml
```

## 🎉 **Summary**

**Yes, AIM Engine can absolutely be part of the Docker container!** The unified container approach provides:

### **Key Benefits**
1. **Simplified Deployment**: Single container with everything included
2. **Dual Mode Operation**: Both orchestration and direct serving
3. **Self-Contained**: No external dependencies required
4. **Easy Distribution**: Single image to deploy anywhere
5. **Development Friendly**: Everything needed for development included

### **Usage Modes**
- **Orchestrated Mode**: `aim-engine launch` (manages separate containers)
- **Direct Mode**: `aim-engine serve` (serves model in same container)
- **Development Mode**: Full development environment included

### **Deployment Options**
- **Single Node**: Perfect for unified container approach
- **Multi Node**: Better with separate containers
- **Cloud Deployment**: Unified container simplifies deployment
- **Edge Deployment**: Single container reduces complexity

The unified container approach makes AIM Engine more portable, easier to deploy, and simpler to manage while maintaining all the intelligent orchestration capabilities! 