# AIM Engine - Container Location & Management Guide

## 🎯 **Where is the Container?**

The container in AIM Engine is a **Docker container** that runs on your local system. Here's exactly where and how it's managed:

## 🐳 **Container Location & Architecture**

### **Container Type**
- **Base Image**: `rocm/vllm:latest` (AMD ROCm vLLM container)
- **Runtime**: Docker container running on your local machine
- **Purpose**: AI model inference endpoint serving

### **Physical Location**
```
Your Local Machine
├── Docker Engine
│   ├── Container: aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
│   │   ├── Image: rocm/vllm:latest
│   │   ├── Model: Qwen/Qwen3-32B (loaded from Hugging Face)
│   │   ├── vLLM Server: Running on port 8000
│   │   └── GPU Access: 4 GPUs allocated
│   └── Other containers...
└── AIM Engine (Python application)
    ├── Recipe selection
    ├── Configuration generation
    └── Container management
```

## 🔧 **Container Management Process**

### **Step 1: Container Creation**
```python
# aim_docker_manager.py - launch_container()
def launch_container(self, config: Dict, container_name: str, gpu_count: int) -> Dict:
    # Build Docker run command
    cmd = ["docker", "run"]
    
    # Container name
    cmd.extend(["--name", container_name])
    
    # Detached mode (run in background)
    cmd.append("-d")
    
    # GPU allocation
    if gpu_count > 0:
        cmd.extend(["--gpus", f"all"])
    
    # Port mapping (host:container)
    port = config.get("port", 8000)
    cmd.extend(["-p", f"{port}:{port}"])
    
    # Environment variables
    for key, value in config.get("environment", {}).items():
        cmd.extend(["-e", f"{key}={value}"])
    
    # Volume mounts
    for volume in config.get("volumes", []):
        cmd.extend(["-v", volume])
    
    # Base image
    cmd.append(self.base_image)  # rocm/vllm:latest
    
    # Command and arguments
    command = config.get("command", "")
    if command:
        cmd.extend(command.split())
```

### **Step 2: Container Naming Convention**
```python
# Container name format
container_name = f"aim-engine-{model_id.replace('/', '-').lower()}-{gpu_count}gpu-{precision}-{backend}"

# Example: aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Step 3: Container Launch Command**
```bash
# Actual Docker command executed
docker run \
  --name aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm \
  -d \
  --gpus all \
  -p 8000:8000 \
  -e HIP_VISIBLE_DEVICES=0,1,2,3 \
  -e NCCL_DEBUG=INFO \
  -v /workspace/models:/workspace/models \
  rocm/vllm:latest \
  --model Qwen/Qwen3-32B \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-batch-size 32 \
  --max-context-len 32768 \
  --gpu-memory-utilization 0.9 \
  --trust-remote-code true \
  --port 8000
```

## 📍 **Container Location Details**

### **1. Docker Engine Location**
- **Host**: Your local machine
- **Docker Engine**: Manages all containers
- **Storage**: Docker's internal storage system

### **2. Container Runtime Location**
```bash
# Check running containers
docker ps

# Output example:
CONTAINER ID   IMAGE              COMMAND                  CREATED         STATUS         PORTS                    NAMES
abc123def456   rocm/vllm:latest   "python -m vllm.entry…"   2 minutes ago   Up 2 minutes   0.0.0.0:8000->8000/tcp   aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **3. Container File System**
```
Container Internal Structure (rocm/vllm:latest)
├── /workspace/
│   ├── models/           # Model storage (mounted from host)
│   └── vllm/            # vLLM installation
├── /opt/conda/          # Python environment
├── /usr/local/          # System libraries
└── /dev/                # Device access (GPUs)
```

### **4. Network Access**
- **Host Port**: 8000 (accessible from your machine)
- **Container Port**: 8000 (internal vLLM server)
- **URL**: `http://localhost:8000` (from your machine)

## 🔍 **Container Management Commands**

### **List All AIM Engine Containers**
```bash
# List running containers
docker ps --filter "name=aim-engine"

# List all containers (including stopped)
docker ps -a --filter "name=aim-engine"
```

### **Check Container Status**
```bash
# Check specific container
docker ps --filter "name=aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm"

# Get container details
docker inspect aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **View Container Logs**
```bash
# View container logs
docker logs aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Follow logs in real-time
docker logs -f aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# View last 100 lines
docker logs --tail 100 aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Execute Commands in Container**
```bash
# Run a command in the container
docker exec -it aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm bash

# Check GPU usage inside container
docker exec aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm rocm-smi

# Check vLLM processes
docker exec aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm ps aux | grep vllm
```

## 🛠️ **Container Lifecycle Management**

### **Start Container**
```bash
# Start a stopped container
docker start aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Stop Container**
```bash
# Stop container (preserves data)
docker stop aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Using AIM Engine
aim-engine stop --container aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Remove Container**
```bash
# Remove container (deletes all data)
docker rm aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Force remove running container
docker rm -f aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

### **Cleanup All AIM Containers**
```bash
# Stop and remove all AIM Engine containers
docker stop $(docker ps -q --filter "name=aim-engine")
docker rm $(docker ps -aq --filter "name=aim-engine")
```

## 📊 **Container Resource Usage**

### **GPU Resources**
```bash
# Check GPU usage
rocm-smi

# Check GPU usage from container perspective
docker exec aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm rocm-smi
```

### **Memory Usage**
```bash
# Check container memory usage
docker stats aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Check all containers
docker stats
```

### **Disk Usage**
```bash
# Check container disk usage
docker system df

# Check specific container disk usage
docker system df -v
```

## 🔧 **Container Configuration**

### **Environment Variables**
```bash
# View container environment variables
docker exec aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm env | grep -E "(CUDA|NCCL|VLLM)"
```

### **Volume Mounts**
```bash
# Check volume mounts
docker inspect aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm | grep -A 10 "Mounts"
```

### **Network Configuration**
```bash
# Check network configuration
docker inspect aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm | grep -A 5 "NetworkSettings"
```

## 🚀 **Container Access & Testing**

### **Health Check**
```bash
# Check if endpoint is healthy
curl http://localhost:8000/health

# Check vLLM models endpoint
curl http://localhost:8000/v1/models
```

### **Inference Test**
```bash
# Test inference
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### **Performance Monitoring**
```bash
# Monitor container performance
docker stats aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm

# Check vLLM metrics
curl http://localhost:8000/metrics
```

## 🎯 **Key Points About Container Location**

### **1. Local Deployment**
- ✅ **Container runs on your local machine**
- ✅ **No cloud or remote deployment**
- ✅ **Direct access to local GPUs**
- ✅ **Full control over resources**

### **2. Resource Isolation**
- ✅ **Each model gets its own container**
- ✅ **Isolated GPU allocation**
- ✅ **Independent port binding**
- ✅ **Separate environment variables**

### **3. Data Persistence**
- ✅ **Model data mounted from host**
- ✅ **Container can be stopped/started**
- ✅ **Data preserved between restarts**
- ✅ **Easy backup and migration**

### **4. Scalability**
- ✅ **Multiple containers can run simultaneously**
- ✅ **Different models on different ports**
- ✅ **Independent resource allocation**
- ✅ **Easy horizontal scaling**

## 🎉 **Summary**

The container in AIM Engine is a **Docker container running on your local machine** that:

1. **Uses the `rocm/vllm:latest` base image**
2. **Runs the vLLM inference server**
3. **Has access to your local GPUs**
4. **Serves the AI model on a local port**
5. **Is managed by Docker Engine**
6. **Can be accessed via `http://localhost:8000`**

The container provides a **complete, isolated environment** for running AI model inference with optimal performance and resource management! 