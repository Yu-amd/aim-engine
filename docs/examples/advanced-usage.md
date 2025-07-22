# AIM Engine - Advanced Usage Examples

## 🎯 **Overview**

This guide provides advanced usage examples for AIM Engine, covering complex deployment scenarios, production configurations, and troubleshooting techniques.

## 🚀 **Advanced Deployment Scenarios**

### **Example 1: Multi-Model Deployment**

Deploy multiple models with different configurations on the same system:

```bash
# Deploy a large model for heavy workloads
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --port 8000

# Deploy a smaller model for quick responses
aim-engine launch Llama-3-8B 1 --precision fp16 --port 8001

# Deploy a specialized model for specific tasks
aim-engine launch Mistral-7B-Instruct 2 --precision bf16 --port 8002

# List all running endpoints
aim-engine list
```

**Output:**
```
Running endpoints:
- aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm (port 8000)
- aim-engine-llama-3-8b-1gpu-fp16-vllm (port 8001)
- aim-engine-mistral-7b-instruct-2gpu-bf16-vllm (port 8002)
```

### **Example 2: Load Balancing Setup**

Deploy multiple instances of the same model for load balancing:

```bash
# Deploy primary instance
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --port 8000 --container qwen-primary

# Deploy secondary instance
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --port 8001 --container qwen-secondary

# Deploy tertiary instance
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --port 8002 --container qwen-tertiary
```

**Load Balancer Configuration (nginx):**
```nginx
upstream qwen_backend {
    server localhost:8000;
    server localhost:8001;
    server localhost:8002;
}

server {
    listen 80;
    location / {
        proxy_pass http://qwen_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### **Example 3: Production Deployment with Monitoring**

Deploy with comprehensive monitoring and health checks:

```bash
# Deploy with custom container name and monitoring
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-production \
  --enable-metrics \
  --metrics-port 9090

# Check detailed status
aim-engine status qwen-production

# Monitor performance
docker stats qwen-production

# Check GPU usage
rocm-smi
```

### **Example 4: Development Environment Setup**

Set up a development environment with hot reloading:

```bash
# Deploy development instance with volume mounting
docker run -it --gpus all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /workspace/models:/workspace/models \
  -v /workspace/aim-engine:/opt/aim-engine \
  aim-engine-unified:latest

# Inside container, launch development model
aim-engine launch Qwen/Qwen3-32B 2 --precision fp16 --port 8000

# Make changes to code and restart
docker restart qwen-development
```

## 🔧 **Advanced Configuration Examples**

### **Example 1: Custom Recipe Usage**

Create and use a custom recipe for specific hardware:

```yaml
# custom-qwen-recipe.yaml
recipe_id: qwen3-32b-custom-config
model_id: Qwen/Qwen3-32B
hardware:
  gpu_count: 4
  gpu_type: MI300X
  memory_requirement: 64GB
precision: bf16
backend: vllm
config:
  tensor_parallel_size: 4
  max_model_len: 16384
  gpu_memory_utilization: 0.95
  dtype: bfloat16
  trust_remote_code: true
  max_num_batched_tokens: 8192
  max_num_seqs: 256
  quantization: null
  enforce_eager: false
  max_paddings: 8192
```

```bash
# Use custom recipe
aim-engine launch Qwen/Qwen3-32B 4 --recipe custom-qwen-recipe.yaml
```

### **Example 2: Environment-Specific Configuration**

Deploy with environment-specific settings:

```bash
# Development environment
aim-engine launch Qwen/Qwen3-32B 2 \
  --precision fp16 \
  --port 8000 \
  --container qwen-dev \
  --env-file .env.dev

# Staging environment
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-staging \
  --env-file .env.staging

# Production environment
aim-engine launch Qwen/Qwen3-32B 8 \
  --precision bf16 \
  --port 8000 \
  --container qwen-prod \
  --env-file .env.prod
```

### **Example 3: Resource-Constrained Deployment**

Deploy in resource-constrained environments:

```bash
# Deploy with memory limits
aim-engine launch Qwen/Qwen3-32B 2 \
  --precision fp16 \
  --memory-limit 32GB \
  --container qwen-memory-limited

# Deploy with CPU limits
aim-engine launch Qwen/Qwen3-32B 1 \
  --precision fp16 \
  --cpu-limit 4 \
  --container qwen-cpu-limited

# Deploy with network limits
aim-engine launch Qwen/Qwen3-32B 2 \
  --precision fp16 \
  --network-mode host \
  --container qwen-network-limited
```

## 🐳 **Container Orchestration Examples**

### **Example 1: Docker Compose Setup**

Create a multi-service deployment with Docker Compose:

```yaml
# docker-compose.yml
version: '3.8'

services:
  aim-engine:
    image: aim-engine-unified:latest
    container_name: aim-engine-orchestrator
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./models:/workspace/models
    environment:
      - AIM_DEBUG=1
    ports:
      - "8080:8080"
    restart: unless-stopped

  qwen-model:
    image: rocm/vllm:latest
    container_name: qwen-inference
    command: >
      python -m vllm.entrypoints.openai.api_server
      --model Qwen/Qwen3-32B
      --tensor-parallel-size 4
      --host 0.0.0.0
      --port 8000
    ports:
      - "8000:8000"
    deploy:
      resources:
        reservations:
          devices:
              count: 4
              capabilities: [gpu]
    restart: unless-stopped

  monitoring:
    image: prom/prometheus:latest
    container_name: aim-monitoring
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped
```

### **Example 2: Kubernetes Deployment**

Deploy AIM Engine on Kubernetes:

```yaml
# aim-engine-deployment.yaml
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
        image: aim-engine-unified:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: models
          mountPath: /workspace/models
        resources:
          limits:
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
      - name: models
        persistentVolumeClaim:
          claimName: models-pvc
```

## 🔍 **Advanced Monitoring and Debugging**

### **Example 1: Comprehensive Monitoring Setup**

Set up monitoring for production deployments:

```bash
# Deploy with Prometheus metrics
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-monitored \
  --enable-metrics \
  --metrics-port 9090

# Monitor with custom dashboard
curl -X GET http://localhost:9090/metrics

# Check specific metrics
curl -X GET http://localhost:9090/metrics | grep vllm
```

### **Example 2: Performance Profiling**

Profile model performance and resource usage:

```bash
# Deploy with profiling enabled
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-profiled \
  --enable-profiling

# Monitor real-time performance
watch -n 1 'docker stats qwen-profiled --no-stream'

# Check GPU utilization
watch -n 1 'rocm-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv'

# Profile inference performance
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100,
    "temperature": 0.7
  }' \
  -w "\nTime: %{time_total}s\n"
```

### **Example 3: Advanced Logging and Debugging**

Set up comprehensive logging for debugging:

```bash
# Deploy with debug logging
export AIM_DEBUG=1
export AIM_LOG_LEVEL=DEBUG

aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-debug \
  --log-level debug

# Follow logs in real-time
docker logs -f qwen-debug

# Check specific log patterns
docker logs qwen-debug | grep -i error
docker logs qwen-debug | grep -i warning

# Export logs for analysis
docker logs qwen-debug > qwen-debug.log
```

## 🔧 **Troubleshooting Advanced Issues**

### **Example 1: Memory Issues**

Handle memory-related problems:

```bash
# Check available memory
free -h

# Check GPU memory
rocm-smi

# Deploy with memory monitoring
aim-engine launch Qwen/Qwen3-32B 2 \
  --precision fp16 \
  --port 8000 \
  --container qwen-memory-monitored \
  --memory-limit 32GB

# Monitor memory usage
watch -n 1 'docker stats qwen-memory-monitored --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'
```

### **Example 2: Network Issues**

Troubleshoot network connectivity problems:

```bash
# Check network connectivity
docker network ls
docker network inspect bridge

# Deploy with network debugging
aim-engine launch Qwen/Qwen3-32B 2 \
  --precision fp16 \
  --port 8000 \
  --container qwen-network-debug \
  --network-mode host

# Test connectivity
curl -v http://localhost:8000/health
telnet localhost 8000

# Check port usage
netstat -tulpn | grep 8000
lsof -i :8000
```

### **Example 3: GPU Issues**

Handle GPU-related problems:

```bash
# Check GPU availability
rocm-smi
rocm-smi -L

# Check GPU driver
rocm-smi --query-gpu=driver_version --format=csv

# Deploy with GPU debugging
aim-engine launch Qwen/Qwen3-32B 1 \
  --precision fp16 \
  --port 8000 \
  --container qwen-gpu-debug \
  --gpu-debug

# Monitor GPU usage
watch -n 1 'rocm-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv'
```

## 🎯 **Production Best Practices**

### **Example 1: High Availability Setup**

Set up high availability deployment:

```bash
# Deploy primary instance
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-primary \
  --restart-policy always

# Deploy backup instance
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8001 \
  --container qwen-backup \
  --restart-policy always

# Set up health check script
cat > health-check.sh << 'EOF'
#!/bin/bash
PRIMARY_URL="http://localhost:8000/health"
BACKUP_URL="http://localhost:8001/health"

if curl -f $PRIMARY_URL > /dev/null 2>&1; then
    echo "Primary endpoint healthy"
    exit 0
elif curl -f $BACKUP_URL > /dev/null 2>&1; then
    echo "Backup endpoint healthy"
    exit 0
else
    echo "Both endpoints down"
    exit 1
fi
EOF

chmod +x health-check.sh
```

### **Example 2: Security Hardening**

Deploy with security best practices:

```bash
# Deploy with security options
aim-engine launch Qwen/Qwen3-32B 4 \
  --precision bf16 \
  --port 8000 \
  --container qwen-secure \
  --read-only \
  --no-new-privileges \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  --user 1000:1000

# Set up firewall rules
sudo ufw allow 8000/tcp
sudo ufw deny 8000/tcp from 192.168.1.0/24
```

### **Example 3: Backup and Recovery**

Set up backup and recovery procedures:

```bash
# Create backup script
cat > backup-models.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/models/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup model configurations
cp -r /workspace/models/* $BACKUP_DIR/

# Backup container configurations
docker inspect qwen-primary > $BACKUP_DIR/qwen-primary-config.json
docker inspect qwen-backup > $BACKUP_DIR/qwen-backup-config.json

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup-models.sh

# Schedule regular backups
echo "0 2 * * * /path/to/backup-models.sh" | crontab -
```

## 🎉 **Summary**

These advanced examples demonstrate:

### **Key Capabilities**
- **Multi-Model Deployment**: Run multiple models simultaneously
- **Load Balancing**: Distribute traffic across multiple instances
- **Production Monitoring**: Comprehensive health checks and metrics
- **Advanced Configuration**: Custom recipes and environment-specific settings
- **Troubleshooting**: Debug complex issues effectively

### **Best Practices**
- **Resource Management**: Efficient use of available hardware
- **Security**: Proper isolation and access controls
- **Monitoring**: Real-time performance tracking
- **Backup**: Regular backup and recovery procedures
- **High Availability**: Redundant deployment configurations

### **Production Readiness**
- **Scalability**: Support for horizontal and vertical scaling
- **Reliability**: Comprehensive error handling and recovery
- **Maintainability**: Clear logging and debugging capabilities
- **Security**: Industry-standard security practices

---

**AIM Engine** - Advanced AI Model Deployment Made Simple! 🚀 