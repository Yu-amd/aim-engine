# AIM Engine Kubernetes Documentation

This directory contains comprehensive documentation for deploying AIM Engine in production Kubernetes environments with AMD GPU support.

## **Documentation Overview**

### **Core Guides**

- **[Production Deployment](PRODUCTION.md)** - Complete production deployment guide
- **[AMD GPU Setup](amd-gpu-setup.md)** - AMD GPU configuration and troubleshooting
- **[Recipe System](recipe-kubernetes-mapping.md)** - Recipe integration with Kubernetes

### **Specialized Topics**

- **[Recipe Implications](recipe-implications-summary.md)** - Impact of recipe system on deployment

## **Quick Start**

### **Production Deployment**

For production Kubernetes clusters:

```bash
# Complete setup (fresh node)
sudo ../scripts/setup-complete-kubernetes.sh

# Deploy to existing cluster
sudo ../scripts/deploy-aim-engine.sh
```

### **Prerequisites**

- **Hardware**: AMD GPU with ROCm support (MI300X, MI325X, etc.)
- **OS**: Ubuntu 22.04+ or compatible Linux distribution
- **Resources**: Minimum 16GB RAM (32GB+ recommended for large models)
- **Network**: Internet access for package downloads
- **Permissions**: Root access required

## **Deployment Options**

### **1. Complete Setup (Recommended)**

Best for fresh nodes or when you want everything set up automatically:

```bash
sudo ../scripts/setup-complete-kubernetes.sh
```

**What this does:**
- Sets up complete Kubernetes cluster
- Configures AMD GPU support
- Builds and pushes AIM Engine image to local registry
- Deploys AIM Engine with optimal settings

### **2. Existing Cluster Deployment**

For existing Kubernetes clusters:

```bash
sudo ../scripts/deploy-aim-engine.sh
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
sudo ../scripts/deploy-aim-engine.sh

# Large model (32B)
sudo ../scripts/deploy-aim-engine.sh --model Qwen/Qwen3-32B --memory-limit 80Gi

# Custom model
sudo ../scripts/deploy-aim-engine.sh --model "your-model/name"
```

### **Resource Allocation**

```bash
# GPU allocation
sudo ../scripts/deploy-aim-engine.sh --gpu-count 2

# Memory allocation
sudo ../scripts/deploy-aim-engine.sh --memory-limit 64Gi --memory-request 32Gi

# Precision selection
sudo ../scripts/deploy-aim-engine.sh --precision bfloat16
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

## **Troubleshooting**

### **Common Issues**

| Issue | Solution |
|-------|----------|
| Image pull fails | Check local registry: `curl http://localhost:5000/v2/_catalog` |
| Pod stuck in Pending | Check GPU labels: `kubectl get nodes --show-labels` |
| Container crashes | Check logs: `kubectl logs -n aim-engine <pod-name>` |
| Service not accessible | Check NodePort: `kubectl get svc -n aim-engine` |

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
```

## **Advanced Topics**

### **Production Considerations**

- **High Availability**: Deploy multiple replicas
- **Load Balancing**: Use LoadBalancer or Ingress
- **Monitoring**: Deploy Prometheus and Grafana
- **Logging**: Configure centralized logging
- **Security**: Use RBAC and network policies
- **Backup**: Regular etcd backups

### **Multi-Node Clusters**

For multi-node clusters:

1. **Master node**: Run setup script
2. **Worker nodes**: Join cluster using provided join command
3. **GPU nodes**: Ensure AMD GPU support on each GPU node
4. **Deployment**: Use node selectors for GPU allocation

### **Custom Helm Values**

Create a custom `values.yaml`:

```yaml
image:
  repository: localhost:5000/aim-vllm
  tag: latest
  pullPolicy: IfNotPresent

aim_engine:
  recipe:
    auto_select: false
    model_id: "Qwen/Qwen3-32B"
    precision: bfloat16
    gpu_count: 2

resources:
  requests:
    memory: 64Gi
    cpu: "4"
    amd.com/gpu: 2
  limits:
    memory: 80Gi
    cpu: "8"
    amd.com/gpu: 2

service:
  type: NodePort
  port: 8000
  targetPort: 8000
```

Deploy with custom values:

```bash
helm install aim-engine ../helm -f custom-values.yaml -n aim-engine
```

## **Cleanup**

### **Remove Deployment**

```bash
# Basic cleanup (removes Kubernetes resources + registry)
sudo ../scripts/cleanup-kubernetes.sh

# Remove images too
sudo ../scripts/cleanup-kubernetes.sh --images

# Complete cleanup (everything)
sudo ../scripts/cleanup-kubernetes.sh --all
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

## **Support**

For issues and questions:
- Check the troubleshooting sections in the documentation
- Review the production deployment guide
- Verify GPU setup and resource allocation
