# AIM Engine Kubernetes Deployment

This directory contains everything you need to deploy AIM Engine to production Kubernetes clusters with AMD GPU support and intelligent recipe-based optimization.

## **Quick Start**

### **Complete Setup (Fresh Node)**

For a fresh node with no existing Kubernetes cluster:

```bash
# Set up complete Kubernetes cluster with AMD GPU support
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

This script handles everything:
- ✅ System preparation and kernel configuration
- ✅ Local container registry setup
- ✅ AIM Engine image build and push to local registry
- ✅ Kubernetes cluster installation
- ✅ AMD GPU support configuration
- ✅ AIM Engine deployment with Helm

### **Deploy to Existing Cluster**

For existing Kubernetes clusters:

```bash
# Deploy with default settings
sudo ./k8s/scripts/deploy-aim-engine.sh

# Deploy with custom model
sudo ./k8s/scripts/deploy-aim-engine.sh --model Qwen/Qwen3-32B --memory-limit 80Gi

# Deploy with multiple GPUs
sudo ./k8s/scripts/deploy-aim-engine.sh --gpu-count 2 --memory-limit 64Gi
```

## **Recipe-Aware Features**

AIM Engine includes intelligent recipe-based optimization that automatically selects the best configuration for your hardware and model requirements.

### **1. Automatic Recipe Selection**

**Feature**: Pre-deployment hooks that automatically select optimal recipes based on:
- Available GPU count and type
- Model requirements and characteristics
- Performance targets and constraints
- Resource availability

```bash
# Deploy with automatic recipe selection
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set aim_engine.model_id=Qwen/Qwen3-32B
```

### **2. Dynamic Configuration**

**Feature**: Helm charts that automatically configure deployments based on selected recipes:
- Dynamic resource allocation
- Automatic command and argument generation
- Environment variable configuration
- Performance optimization settings

### **3. Recipe Validation**

**Feature**: Kubernetes admission controllers that validate recipe configurations:
- Recipe compatibility checking
- Resource requirement validation
- Performance constraint verification
- Prevents invalid deployments

### **4. Recipe-Based Monitoring**

**Feature**: Comprehensive monitoring with recipe-specific metrics:
- Custom Prometheus metrics for recipe performance
- Recipe-specific alerting rules
- Performance baseline tracking
- Resource utilization monitoring

### **5. Performance Dashboards**

**Feature**: Grafana dashboards for recipe performance visualization:
- Recipe selection overview panels
- Performance comparison charts
- Resource utilization graphs
- Optimization recommendation displays

## **Features**

| **Feature** | **Production** |
|-------------|----------------|
| **GPU Support** | Full AMD GPU integration |
| **Recipe Optimization** | Automatic configuration selection |
| **Scalability** | Multi-node cluster support |
| **Monitoring** | Built-in observability with recipe metrics |
| **Security** | RBAC and network policies |
| **Storage** | Persistent volume support |
| **Load Balancing** | Service mesh ready |
| **High Availability** | Multi-replica support |
| **Validation** | Admission controllers for recipe validation |

## **Prerequisites**

### **Production Requirements**

- **Hardware**: AMD GPU with ROCm support (MI300X, MI325X, etc.)
- **OS**: Ubuntu 22.04+ or compatible Linux distribution
- **Resources**: Minimum 16GB RAM (32GB+ recommended for large models)
- **Network**: Internet access for package downloads
- **Permissions**: Root access required

### **System Requirements**

- **CPU**: 4+ cores recommended
- **Memory**: 16GB+ RAM
- **Storage**: 50GB+ free disk space
- **Network**: Stable internet connection

## **Deployment Options**

### **1. Complete Setup (Recommended)**

Best for fresh nodes or when you want everything set up automatically:

```bash
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

**What this does:**
- Sets up complete Kubernetes cluster
- Configures AMD GPU support
- Builds and pushes AIM Engine image
- Deploys AIM Engine with optimal settings

### **2. Existing Cluster Deployment**

For existing Kubernetes clusters:

```bash
sudo ./k8s/scripts/deploy-aim-engine.sh
```

**What this does:**
- Checks cluster health
- Sets up local registry if needed
- Builds and pushes AIM Engine image
- Deploys AIM Engine with custom configuration

## **Configuration**

### **Model Selection**

```bash
# Default model (7B)
sudo ./k8s/scripts/deploy-aim-engine.sh

# Large model (32B)
sudo ./k8s/scripts/deploy-aim-engine.sh --model Qwen/Qwen3-32B --memory-limit 80Gi

# Custom model
sudo ./k8s/scripts/deploy-aim-engine.sh --model "your-model/name"
```

### **Resource Allocation**

```bash
# GPU allocation
sudo ./k8s/scripts/deploy-aim-engine.sh --gpu-count 2

# Memory allocation
sudo ./k8s/scripts/deploy-aim-engine.sh --memory-limit 64Gi --memory-request 32Gi

# Precision selection
sudo ./k8s/scripts/deploy-aim-engine.sh --precision bfloat16
```

### **Recipe Configuration**

```bash
# Automatic recipe selection
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set aim_engine.model_id=Qwen/Qwen3-32B

# Manual recipe override
helm install aim-engine ./helm \
  --set aim_engine.auto_select=false \
  --set aim_engine.gpu_count=4 \
  --set aim_engine.precision=bf16 \
  --set aim_engine.backend=vllm

# Custom recipe parameters
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set aim_engine.overrides.gpu_count=8 \
  --set aim_engine.overrides.precision=fp16 \
  --set aim_engine.overrides.vllm_args.max_model_len=16384
```

## **Verification**

### **Check Deployment Status**

```bash
# Check pod status
kubectl get pods -n aim-engine

# Check service
kubectl get svc -n aim-engine

# Check logs
kubectl logs -f -n aim-engine -l app.kubernetes.io/name=aim-engine
```

### **Test Endpoints**

```bash
# Get NodePort
NODEPORT=$(kubectl get svc -n aim-engine aim-engine-service -o jsonpath='{.spec.ports[0].nodePort}')

# Health check
curl http://localhost:${NODEPORT}/health

# List models
curl http://localhost:${NODEPORT}/v1/models

# Test inference
curl -X POST http://localhost:${NODEPORT}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

### **Recipe Verification**

```bash
# Check recipe selection
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# Verify deployment configuration
kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml

# Check monitoring setup
kubectl get servicemonitor -n aim-engine
kubectl get prometheusrule -n aim-engine
```

## **Advanced Usage**

### **Custom Recipe Development**

```bash
# Create custom recipe
cat > custom-recipe.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-recipe
data:
  recipe.yaml: |
    recipe_id: custom-qwen-32b-4gpu-bf16
    huggingface_id: Qwen/Qwen3-32B
    hardware: MI300X
    gpu_count: 4
    precision: bf16
    backend: vllm
    config:
      args:
        max_model_len: 32768
        max_num_batched_tokens: 8192
        gpu_memory_utilization: 0.9
    performance:
      expected_tokens_per_second: 5000
      expected_latency_ms: 100
    resources:
      requests:
        amd.com/gpu: "4"
        memory: "64Gi"
        cpu: "16"
      limits:
        amd.com/gpu: "4"
        memory: "128Gi"
        cpu: "32"
EOF

# Apply custom recipe
kubectl apply -f custom-recipe.yaml -n aim-engine

# Deploy with custom recipe
helm install aim-engine ./helm \
  --set aim_engine.auto_select=false \
  --set aim_engine.custom_recipe=custom-recipe
```

### **Multi-Model Deployment**

```bash
# Deploy multiple models with different recipes
helm install aim-engine-qwen ./helm \
  --set aim_engine.model_id=Qwen/Qwen3-32B \
  --set aim_engine.gpu_count=4

helm install aim-engine-llama ./helm \
  --set aim_engine.model_id=meta-llama/Llama-2-70b-chat-hf \
  --set aim_engine.gpu_count=8 \
  --set aim_engine.precision=fp16
```

### **Performance Optimization**

```bash
# Deploy with performance monitoring
helm install aim-engine ./helm \
  --set monitoring.enabled=true \
  --set aim_engine.performance_tuning=true \
  --set aim_engine.vllm_args.max_batch_size=64

# Monitor performance
kubectl port-forward service/prometheus 9090:9090 -n monitoring
# Access Grafana dashboard for performance insights
```

## **Cleanup**

### **Remove Deployment**

```bash
# Basic cleanup (removes Kubernetes resources + registry)
sudo ./k8s/scripts/cleanup-kubernetes.sh

# Remove images too
sudo ./k8s/scripts/cleanup-kubernetes.sh --images

# Complete cleanup (everything)
sudo ./k8s/scripts/cleanup-kubernetes.sh --all
```

### **Manual Cleanup**

```bash
# Remove Helm release
helm uninstall aim-engine -n aim-engine

# Remove namespace
kubectl delete namespace aim-engine

# Stop registry
docker stop local-registry
docker rm local-registry
```

## **Troubleshooting**

### **Common Issues**

| Issue | Solution |
|-------|----------|
| Image pull fails | Check local registry: `curl http://localhost:5000/v2/_catalog` |
| Pod stuck in Pending | Check GPU labels: `kubectl get nodes --show-labels` |
| Container crashes | Check logs: `kubectl logs -n aim-engine <pod-name>` |
| Service not accessible | Check NodePort: `kubectl get svc -n aim-engine` |
| Recipe selection fails | Check recipe selector logs: `kubectl logs job/aim-engine-recipe-selector -n aim-engine` |

### **Recipe-Specific Issues**

```bash
# Check recipe selector logs
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# Verify recipe availability
kubectl get configmap -n aim-engine | grep recipe

# Check GPU availability
kubectl describe node | grep amd.com/gpu

# Check admission controller logs
kubectl logs deployment/aim-engine-recipe-validator -n aim-engine
```

### **Useful Commands**

```bash
# Check cluster status
kubectl cluster-info

# Check GPU availability
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Check pod events
kubectl describe pod -n aim-engine <pod-name>

# Check service endpoints
kubectl get endpoints -n aim-engine

# Check performance metrics
kubectl port-forward service/prometheus 9090:9090 -n monitoring
# Query: aim_performance_tokens_per_second
```

## **Documentation**

- **[Complete Deployment Guide](KUBERNETES_DEPLOYMENT.md)** - Detailed setup and configuration
- **[Production Guide](docs/PRODUCTION.md)** - Production best practices
- **[AMD GPU Setup](docs/amd-gpu-setup.md)** - GPU configuration guide
- **[Recipe System](docs/recipe-kubernetes-mapping.md)** - Recipe integration details

## **Benefits**

### **Performance Optimization**
- **Automatic Optimization**: Recipes automatically optimize for hardware
- **Performance Monitoring**: Real-time performance tracking and alerting
- **Resource Efficiency**: Optimal resource allocation based on recipes

### **Operational Efficiency**
- **Zero Configuration**: Automatic recipe selection reduces manual configuration
- **Consistent Deployments**: Recipe-based configuration ensures consistency
- **Validation**: Admission controllers prevent invalid deployments

### **Resource Management**
- **Dynamic Allocation**: Resources allocated based on recipe requirements
- **Efficient Utilization**: Optimal GPU and memory usage
- **Scalability**: Easy scaling with recipe-aware configurations
