# AIM Engine - Production Architecture: Container Interaction

## 🏗️ **How Two Containers Work Together in Production**

In a real-world production environment, **AIM Engine** and the **vLLM base container** work together using a **Docker-in-Docker (DinD)** or **Docker-outside-of-Docker (DooD)** pattern to create inference endpoints.

## 🐳 **Container Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Production Host                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              AIM Engine Container                       │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │  Container Registry Client                      │   │   │
│  │  │  • Pulls vLLM base image                        │   │   │
│  │  │  • Manages container lifecycle                  │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │  AIM Engine Orchestration                       │   │   │
│  │  │  • Recipe selection                             │   │   │
│  │  │  • Configuration generation                     │   │   │
│  │  │  • Endpoint management                          │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              │ Docker Socket                   │
│                              │ /var/run/docker.sock            │
│                              │                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              vLLM Model Container                      │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │  ROCm/vLLM Base Image                           │   │   │
│  │  │  • rocm/vllm:latest                             │   │   │
│  │  │  • GPU drivers & libraries                      │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │  Model & Inference Engine                       │   │   │
│  │  │  • Hugging Face model                           │   │   │
│  │  │  • vLLM server                                  │   │   │
│  │  │  • API endpoints                                │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 **Step-by-Step Container Interaction**

### **Phase 1: Container Initialization**

```bash
# 1. Production system pulls AIM Engine container
docker pull your-registry.com/aim-engine:latest

# 2. AIM Engine container starts
docker run -d \
  --name aim-engine \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8000-8010:8000-8010 \
  your-registry.com/aim-engine:latest
```

### **Phase 2: vLLM Base Image Preparation**

```bash
# 3. AIM Engine container pulls vLLM base image
# (This happens inside the AIM Engine container)
docker pull rocm/vllm:latest
```

### **Phase 3: Model Endpoint Creation**

```bash
# 4. User requests model deployment
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# 5. AIM Engine container creates vLLM model container
docker run -d \
  --name aim-engine-qwen-4gpu \
  --gpus all \
  -p 8000:8000 \
  -e CUDA_VISIBLE_DEVICES=0,1,2,3 \
  -e VLLM_USE_BF16=1 \
  -v /opt/aim-engine/cache:/root/.cache \
  rocm/vllm:latest \
  python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-32B \
  --tensor-parallel-size 4 \
  --host 0.0.0.0 \
  --port 8000
```

## 🏭 **Real-World Production Flow**

### **1. Container Registry Setup**

```yaml
# Container registries in production
AIM_ENGINE_REGISTRY: "your-registry.com/aim-engine"
VLLM_BASE_REGISTRY: "rocm/vllm"  # Official AMD registry
MODEL_REGISTRY: "huggingface.co"  # Model repository
```

### **2. Production Deployment Script**

```bash
#!/bin/bash
# production-deploy.sh

# Pull AIM Engine container from registry
docker pull $AIM_ENGINE_REGISTRY:latest

# Start AIM Engine orchestrator
docker run -d \
  --name aim-engine-orchestrator \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/aim-engine/config:/opt/aim-engine/config \
  -v /opt/aim-engine/logs:/opt/aim-engine/logs \
  -p 8000-8010:8000-8010 \
  -e AIM_ENGINE_REGISTRY=$AIM_ENGINE_REGISTRY \
  -e VLLM_BASE_REGISTRY=$VLLM_BASE_REGISTRY \
  $AIM_ENGINE_REGISTRY:latest

# AIM Engine now manages vLLM containers automatically
```

### **3. Model Endpoint Creation Process**

```python
# Inside AIM Engine container - what happens when you run:
# aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

def create_model_endpoint(model_id, gpu_count, precision):
    # 1. Select appropriate recipe
    recipe = recipe_selector.select_best_recipe(model_id, gpu_count, precision)
    
    # 2. Generate Docker run command
    docker_cmd = config_generator.generate_docker_command(recipe, gpu_count)
    
    # 3. Pull vLLM base image if not present
    docker_manager.pull_image("rocm/vllm:latest")
    
    # 4. Create and start vLLM container
    container_id = docker_manager.create_container(docker_cmd)
    
    # 5. Wait for endpoint to be ready
    endpoint_manager.wait_for_ready(container_id)
    
    # 6. Register endpoint for management
    endpoint_manager.register_endpoint(container_id, model_id)
    
    return container_id
```

## 🔧 **Container Communication Patterns**

### **Pattern 1: Docker Socket Communication**

```bash
# AIM Engine container communicates with Docker daemon
# to manage vLLM containers

# Inside AIM Engine container
docker ps                    # List running containers
docker logs <container-id>   # Get container logs
docker exec <container-id>   # Execute commands in container
docker stop <container-id>   # Stop container
```

### **Pattern 2: HTTP API Communication**

```bash
# AIM Engine container communicates with vLLM API endpoints

# Health check
curl http://localhost:8000/health

# Model info
curl http://localhost:8000/v1/models

# Inference request
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-32B", "prompt": "Hello"}'
```

### **Pattern 3: Volume Sharing**

```yaml
# Shared volumes between containers
volumes:
  # Model cache shared between AIM Engine and vLLM containers
  - /opt/aim-engine/cache:/root/.cache:rw
  
  # Configuration shared
  - /opt/aim-engine/config:/opt/aim-engine/config:ro
  
  # Logs collected by AIM Engine
  - /opt/aim-engine/logs:/opt/aim-engine/logs:rw
```

## 🚀 **Production Deployment Examples**

### **Example 1: Single Node Production**

```yaml
# docker-compose.production.yml
version: '3.8'

services:
  aim-engine:
    image: your-registry.com/aim-engine:latest
    container_name: aim-engine-prod
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config:/opt/aim-engine/config:ro
      - ./models:/opt/aim-engine/models:ro
      - ./recipes:/opt/aim-engine/recipes:ro
      - ./logs:/opt/aim-engine/logs
      - ./cache:/opt/aim-engine/cache
    ports:
      - "8000-8010:8000-8010"
    environment:
      - AIM_ENGINE_REGISTRY=your-registry.com/aim-engine
      - VLLM_BASE_REGISTRY=rocm/vllm
    networks:
      - aim-engine-network

networks:
  aim-engine-network:
    driver: bridge
```

### **Example 2: Kubernetes Production**

```yaml
# k8s-aim-engine.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aim-engine
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aim-engine
  template:
    metadata:
      labels:
        app: aim-engine
    spec:
      containers:
      - name: aim-engine
        image: your-registry.com/aim-engine:latest
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: config
          mountPath: /opt/aim-engine/config
          readOnly: true
        - name: cache
          mountPath: /opt/aim-engine/cache
        env:
        - name: AIM_ENGINE_REGISTRY
          value: "your-registry.com/aim-engine"
        - name: VLLM_BASE_REGISTRY
          value: "rocm/vllm"
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
      - name: config
        configMap:
          name: aim-engine-config
      - name: cache
        persistentVolumeClaim:
          claimName: aim-engine-cache-pvc
```

## 🔄 **Container Lifecycle Management**

### **Startup Sequence**

```bash
# 1. Production system starts AIM Engine container
docker run -d your-registry.com/aim-engine:latest

# 2. AIM Engine container initializes
# - Loads configuration
# - Checks Docker connectivity
# - Validates recipes and models
# - Starts management services

# 3. User requests model deployment
aim-engine launch Qwen/Qwen3-32B 4

# 4. AIM Engine creates vLLM container
docker run -d rocm/vllm:latest [vllm-args]

# 5. vLLM container starts and loads model
# - Downloads model from Hugging Face
# - Initializes GPU context
# - Starts API server

# 6. AIM Engine monitors and manages endpoint
# - Health checks
# - Log collection
# - Metrics gathering
```

### **Shutdown Sequence**

```bash
# 1. User stops model endpoint
aim-engine stop aim-engine-qwen-4gpu

# 2. AIM Engine stops vLLM container
docker stop aim-engine-qwen-4gpu

# 3. AIM Engine removes vLLM container
docker rm aim-engine-qwen-4gpu

# 4. AIM Engine updates endpoint registry
# - Removes from active endpoints
# - Updates status
# - Cleans up resources
```

## 📊 **Resource Management**

### **GPU Allocation**

```bash
# AIM Engine manages GPU allocation for vLLM containers
docker run -d \
  --name aim-engine-qwen-4gpu \
  --gpus '"device=0,1,2,3"' \  # Specific GPU devices
  -e CUDA_VISIBLE_DEVICES=0,1,2,3 \
  rocm/vllm:latest
```

### **Memory Management**

```bash
# Memory limits for vLLM containers
docker run -d \
  --name aim-engine-qwen-4gpu \
  --memory=64g \              # Container memory limit
  --memory-swap=64g \         # Swap limit
  rocm/vllm:latest
```

### **Network Management**

```bash
# Network configuration for vLLM containers
docker run -d \
  --name aim-engine-qwen-4gpu \
  --network aim-engine-network \
  -p 8000:8000 \              # Port mapping
  rocm/vllm:latest
```

## 🔍 **Monitoring and Observability**

### **Container Health Monitoring**

```python
# AIM Engine monitors vLLM containers
def monitor_vllm_container(container_id):
    # Check container status
    status = docker_manager.get_container_status(container_id)
    
    # Check API health
    health = endpoint_manager.check_health(f"http://localhost:{port}/health")
    
    # Check resource usage
    resources = docker_manager.get_container_stats(container_id)
    
    # Log metrics
    logger.info(f"Container {container_id}: status={status}, health={health}")
    
    return status, health, resources
```

### **Log Aggregation**

```bash
# AIM Engine collects logs from vLLM containers
docker logs aim-engine-qwen-4gpu > /opt/aim-engine/logs/qwen-4gpu.log

# Centralized logging
docker run -d \
  --name aim-engine-qwen-4gpu \
  --log-driver=json-file \
  --log-opt max-size=100m \
  --log-opt max-file=3 \
  rocm/vllm:latest
```

## 🎯 **Key Benefits of This Architecture**

### **Separation of Concerns**
- ✅ **AIM Engine**: Orchestration, management, monitoring
- ✅ **vLLM Container**: Model serving, inference, GPU optimization

### **Scalability**
- ✅ **Horizontal Scaling**: Multiple vLLM containers
- ✅ **Resource Optimization**: Dynamic GPU allocation
- ✅ **Load Balancing**: Multiple endpoints per model

### **Maintainability**
- ✅ **Independent Updates**: Update AIM Engine or vLLM separately
- ✅ **Isolation**: Model containers don't affect orchestrator
- ✅ **Rollback**: Easy to rollback individual components

### **Production Readiness**
- ✅ **High Availability**: AIM Engine can restart vLLM containers
- ✅ **Monitoring**: Centralized monitoring and alerting
- ✅ **Security**: Container isolation and proper permissions

## 🚀 **Summary**

In production, **AIM Engine** and **vLLM base containers** work together through:

1. **Container Registry**: Both containers pulled from registries
2. **Docker Socket**: AIM Engine manages vLLM containers
3. **HTTP APIs**: Communication between containers
4. **Shared Volumes**: Configuration and cache sharing
5. **Resource Management**: GPU, memory, and network allocation

This architecture provides a robust, scalable, and maintainable solution for AI model deployment in production environments! 