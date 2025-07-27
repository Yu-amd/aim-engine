# AIM Engine Kubernetes Deployment

## **Overview**

AIM Engine provides optimized recipe selection for large language model inference, automatically choosing the best configuration based on available GPU resources, precision requirements, and performance KPIs. This guide covers deploying AIM Engine in both development (Minikube) and production (Helm) environments.

## **Quick Start**

### **Choose Your Deployment Approach**

| Environment     | Use Case                       | GPU Support        | Complexity | Setup Time    |
|-----------------|--------------------------------|--------------------|------------|---------------|
| **Development** | Testing, learning, development | Mock server or TGI | Simple     | 5-10 minutes  |
| **Production**  | Real workloads, GPU inference  | Full AMD GPU vLLM  | Advanced   | 30-60 minutes |

### **For Development (Minikube)**
```bash
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Deploy AIM Engine
cd k8s/minikube
./deploy.sh

# Test deployment
./test-recipe.sh
```

### **For Production (Helm)**
```bash
# Install GPU plugin
kubectl create -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Build and push image
docker build -f Dockerfile.aim-vllm -t your-registry.com/aim-vllm:latest .
docker push your-registry.com/aim-vllm:latest

# Deploy with recipe support
cd k8s
./scripts/deploy-with-recipe-support.sh auto your-registry.com latest
```

## **Prerequisites**

### **Development Requirements**
- Minikube installed
- kubectl configured
- Docker installed
- 4GB RAM minimum (8GB recommended)

### **Production Requirements**
- Kubernetes cluster (1.20+)
- AMD GPU nodes with ROCm support
- AMD GPU device plugin installed
- Helm 3.x installed
- Container registry access

## **Recipe Selection**

AIM Engine automatically selects optimal configurations based on:

- **Model size** and requirements
- **Available GPU count** and memory
- **Precision requirements** (bf16, fp16, fp8)
- **Performance targets** and KPIs

### **Example Recipe Configuration**
```yaml
recipe_id: qwen3-32b-4gpu-bf16
model_id: Qwen/Qwen3-32B
gpu_count: 4
precision: bf16
backend: vllm
hardware:
  type: MI300X
  rocm_arch: gfx90a
performance:
  expected_tokens_per_second: 150
  expected_latency_ms: 100
```

## **Features**

### **Recipe Selection**
- **Automatic optimization** based on available resources
- **Configuration overrides** for custom deployments
- **Fallback mechanisms** for optimal performance
- **Recipe validation** through admission controllers

### **Monitoring & Observability**
- **Prometheus metrics** collection and alerting
- **Grafana dashboards** for performance visualization
- **Custom alerts** for recipe-specific issues
- **Performance optimization** recommendations

### **Development Features**
- **Mock server** for quick testing
- **TGI server** for real inference testing
- **Recipe validation** without GPU hardware
- **Easy testing** with included scripts

### **Production Features**
- **AMD GPU support** with ROCm
- **High availability** with multiple replicas
- **Auto-scaling** based on demand
- **Enterprise-grade** monitoring and security

## **Deployment Options**

### **Development Environment (Minikube)**

**Use Case**: Local development, testing, learning
**GPU Support**: Mock server or TGI (no real GPU required)
**Complexity**: Simple

#### **Quick Start**
```bash
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Deploy with mock server
cd k8s/minikube
./deploy.sh

# Deploy with TGI for real inference
./deploy.sh tgi

# Test deployment
./test-recipe.sh
```

#### **Features**
- Recipe selection with mock data
- Monitoring endpoints
- Easy testing and validation
- No GPU hardware required

### **Production Environment (Helm)**

**Use Case**: Real production workloads with GPU inference
**GPU Support**: Full AMD GPU support with ROCm
**Complexity**: Advanced

#### **Quick Start**
```bash
# Prepare cluster
kubectl create -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Build and deploy
docker build -f Dockerfile.aim-vllm -t your-registry.com/aim-vllm:latest .
docker push your-registry.com/aim-vllm:latest

# Deploy with recipe support
cd k8s
./scripts/deploy-with-recipe-support.sh auto your-registry.com latest
```

#### **Features**
- Real GPU inference with AMD ROCm
- Comprehensive monitoring and alerting
- High availability and auto-scaling
- Enterprise-grade security

## **Migration Path**

### **From Development to Production**
1. **Complete testing** in Minikube environment
2. **Set up production cluster** with AMD GPUs
3. **Deploy using production scripts**
4. **Configure monitoring** and alerting

## **Documentation**

### **Essential Guides**
- **[Development Guide](DEVELOPMENT.md)** - Complete Minikube development guide
- **[Production Guide](PRODUCTION.md)** - Complete Helm production guide

### **Specialized Resources**
- **[AMD GPU Setup](amd-gpu-setup.md)** - AMD GPU configuration guide

## **Troubleshooting**

### **Common Issues**

#### **Development Issues**
```bash
# Minikube not starting
minikube status
minikube start --driver=docker --cpus=6 --memory=12288

# Service not accessible
kubectl get pods -n aim-engine
kubectl logs -n aim-engine deployment/aim-engine
```

#### **Production Issues**
```bash
# GPU not available
kubectl get nodes -l amd.com/gpu=true
kubectl get pods -n kube-system | grep amd-device-plugin

# Recipe selection fails
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook
```

## **Next Steps**

1. **Choose your deployment approach** based on your needs
2. **Follow the detailed guide** for your chosen environment
3. **Test thoroughly** before production deployment
4. **Set up monitoring** for production environments
5. **Plan for scaling** and high availability
