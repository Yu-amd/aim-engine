# AIM Engine Kubernetes Deployment

This directory contains everything you need to deploy AIM Engine to Kubernetes clusters, from development (Minikube) to production environments.

## Quick Start

### **Development (Minikube)**
```bash
# Start Minikube with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192

# Deploy AIM Engine to Minikube
cd k8s/minikube
./deploy.sh

# Access the service
minikube service aim-engine-service -n aim-engine
```

### **Production (Full Kubernetes)**
```bash
# Build and push Docker image
docker build -f docker/Dockerfile.aim-vllm -t your-registry.com/aim-vllm:latest .
docker push your-registry.com/aim-vllm:latest

# Deploy using Helm
cd k8s
helm install aim-engine ./helm -f values.yaml

# Or deploy using Kustomize
kubectl apply -k ./production
```

## Environment Comparison

| **Feature** | **Minikube** | **Production** |
|-------------|--------------|----------------|
| **GPU Support** | Mock server | Full GPU access |
| **Resource Limits** | Limited | Full cluster resources |
| **Persistence** | HostPath | Production storage |
| **Monitoring** | Basic | Comprehensive |
| **Scaling** | Single replica | Auto-scaling |

## Prerequisites

### **Minikube Development**
- Docker installed
- Minikube installed
- kubectl configured
- At least 4GB RAM available

### **Production Kubernetes**
- Kubernetes cluster (1.20+)
- AMD GPU operator installed
- Helm 3.x installed
- kubectl configured
- Container registry access

## Configuration

### **Environment Variables**
```bash
# Model configuration
MODEL_ID=Qwen/Qwen3-32B
PRECISION=bf16
GPU_COUNT=4

# Resource limits
MEMORY_LIMIT=64Gi
CPU_LIMIT=16
```

### **Storage Configuration**
```bash
# Model cache persistence
MODEL_CACHE_SIZE=500Gi
MODEL_CACHE_PATH=/workspace/model-cache
```

## Documentation

### **Deployment Guides**
- **[Development Guide](docs/DEVELOPMENT.md)** - Minikube deployment
- **[Production Guide](docs/PRODUCTION.md)** - Production deployment
- **[AMD GPU Setup](docs/amd-gpu-setup.md)** - GPU configuration

### **Advanced Topics**
- **[Recipe Integration](docs/recipe-kubernetes-mapping.md)** - Recipe-based deployment
- **[Monitoring Setup](docs/monitoring-setup.md)** - Prometheus/Grafana

## Deployment Options

### **1. Script-Based Deployment**
```bash
# Minikube
cd k8s/minikube
./deploy.sh

# Production
cd k8s/production
./deploy.sh
```

### **2. Helm Chart Deployment**
```bash
# Install Helm chart
helm install aim-engine ./helm

# Upgrade with custom values
helm upgrade aim-engine ./helm -f custom-values.yaml

# Uninstall
helm uninstall aim-engine
```

### **3. Kustomize Deployment**
```bash
# Apply base configuration
kubectl apply -k ./common

# Apply environment-specific patches
kubectl apply -k ./production
```

## Verification

### **Check Deployment Status**
```bash
# Check pods
kubectl get pods -n aim-engine

# Check services
kubectl get services -n aim-engine

# Check ingress
kubectl get ingress -n aim-engine
```

### **Test Endpoints**
```bash
# Port forward to service
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Test health endpoint
curl http://localhost:8000/health

# Test model endpoint
curl http://localhost:8000/v1/models
```

### **Monitor Logs**
```bash
# View pod logs
kubectl logs -f deployment/aim-engine -n aim-engine

# View events
kubectl get events -n aim-engine --sort-by='.lastTimestamp'
```

## Troubleshooting

### **Common Issues**
- **Pod not starting**: Check resource limits and GPU availability
- **Image pull errors**: Verify registry credentials and image availability
- **GPU not detected**: Ensure AMD GPU operator is installed
- **Storage issues**: Check PVC and storage class configuration

### **Debug Commands**
```bash
# Describe pod for detailed status
kubectl describe pod <pod-name> -n aim-engine

# Check node resources
kubectl describe node <node-name>

# Check GPU operator status
kubectl get pods -n gpu-operator-system
```

## Success!

Your AIM Engine is now deployed and ready to use! 