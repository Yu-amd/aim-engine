# AIM Engine Kubernetes Deployment Guide

This guide covers deploying AIM Engine on Kubernetes clusters with AMD GPU support.

## **Overview**

AIM Engine Kubernetes deployment uses a local container registry to ensure reliable image distribution within the cluster. The setup process:

1. **System Preparation**: Configure system for Kubernetes
2. **Local Registry**: Start local container registry
3. **Image Build**: Build and push AIM Engine image to local registry
4. **Cluster Setup**: Install and configure Kubernetes cluster
5. **GPU Support**: Configure AMD GPU device plugin
6. **Deployment**: Deploy AIM Engine using Helm

## **Prerequisites**

- **Hardware**: AMD GPU with ROCm support (MI300X, MI325X, etc.)
- **OS**: Ubuntu 22.04+ or compatible Linux distribution
- **Resources**: Minimum 16GB RAM (32GB+ recommended for large models)
- **Network**: Internet access for package downloads
- **Permissions**: Root access required

## **Quick Start**

### **Complete Setup (Fresh Node)**

For a fresh node with no existing Kubernetes cluster:

```bash
# Clone the repository
git clone <repository-url>
cd aim-engine

# Run the complete setup script
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

## **Detailed Setup Process**

### **Step 1: System Preparation**

The setup script automatically:
- Updates system packages
- Installs required dependencies
- Disables swap
- Configures kernel modules
- Sets up network parameters

### **Step 2: Local Container Registry**

A local Docker registry is started to store the AIM Engine image:

```bash
# Registry runs on port 5000
docker run -d -p 5000:5000 --name local-registry registry:2
```

**Benefits:**
- Reliable image distribution within cluster
- No dependency on external registries
- Faster image pulls
- Works in air-gapped environments

### **Step 3: Image Build and Push**

The AIM Engine image is built and pushed to the local registry:

```bash
# Build the image
./scripts/build-aim-vllm.sh

# Tag and push to local registry
docker tag aim-vllm:latest localhost:5000/aim-vllm:latest
docker push localhost:5000/aim-vllm:latest
```

### **Step 4: Kubernetes Cluster Setup**

The script installs and configures:
- **Containerd**: Container runtime
- **Kubernetes components**: kubelet, kubeadm, kubectl
- **Cluster initialization**: Single-node cluster setup
- **Calico CNI**: Network plugin
- **Metrics server**: Resource monitoring
- **Local storage provisioner**: Persistent storage

### **Step 5: AMD GPU Support**

AMD GPU support is configured:
- **ROCm packages**: AMD GPU drivers and libraries
- **GPU device plugin**: Kubernetes GPU resource management
- **Device mounts**: /dev/kfd and /dev/dri access

### **Step 6: AIM Engine Deployment**

AIM Engine is deployed using Helm with:
- **Local registry image**: `localhost:5000/aim-vllm:latest`
- **GPU allocation**: Based on available GPUs
- **Resource limits**: Memory and CPU allocation
- **Service exposure**: NodePort for external access
- **Health checks**: Disabled during model loading

## **Configuration Options**

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

### **Service Configuration**

```bash
# NodePort service (default)
sudo ./k8s/scripts/deploy-aim-engine.sh --service-type NodePort

# LoadBalancer service
sudo ./k8s/scripts/deploy-aim-engine.sh --service-type LoadBalancer

# ClusterIP service (internal only)
sudo ./k8s/scripts/deploy-aim-engine.sh --service-type ClusterIP
```

## **Verification and Testing**

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

## **Monitoring and Troubleshooting**

### **Resource Monitoring**

```bash
# Check GPU allocation
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Check pod resources
kubectl describe pod -n aim-engine -l app.kubernetes.io/name=aim-engine

# Check GPU usage
kubectl exec -n aim-engine <pod-name> -- rocm-smi
```

### **Common Issues**

#### **Image Pull Issues**
```bash
# Check if image exists in registry
curl http://localhost:5000/v2/aim-vllm/tags/list

# Rebuild and push image
./scripts/build-aim-vllm.sh
docker tag aim-vllm:latest localhost:5000/aim-vllm:latest
docker push localhost:5000/aim-vllm:latest
```

#### **GPU Allocation Issues**
```bash
# Check GPU device plugin
kubectl get pods -n kube-system | grep amd-gpu-device-plugin

# Check GPU labels
kubectl get nodes --show-labels | grep amd.com/gpu

# Add GPU label if missing
kubectl label node <node-name> amd.com/gpu=true
```

#### **Pod Stuck in Pending**
```bash
# Check pod events
kubectl describe pod -n aim-engine <pod-name>

# Check resource availability
kubectl get nodes -o json | jq '.items[].status.allocatable'
```

## **Cleanup**

### **Remove AIM Engine Deployment**

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

## **Advanced Configuration**

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
helm install aim-engine ./k8s/helm -f custom-values.yaml -n aim-engine
```

### **Multi-Node Clusters**

For multi-node clusters:

1. **Master node**: Run setup script
2. **Worker nodes**: Join cluster using provided join command
3. **GPU nodes**: Ensure AMD GPU support on each GPU node
4. **Deployment**: Use node selectors for GPU allocation

### **Production Considerations**

- **High Availability**: Deploy multiple replicas
- **Load Balancing**: Use LoadBalancer or Ingress
- **Monitoring**: Deploy Prometheus and Grafana
- **Logging**: Configure centralized logging
- **Security**: Use RBAC and network policies
- **Backup**: Regular etcd backups

## **Troubleshooting Guide**

### **Setup Issues**

| Issue | Solution |
|-------|----------|
| Registry not responding | Check if registry container is running |
| Image build fails | Check Docker daemon and disk space |
| Kubernetes init fails | Check system requirements and network |
| GPU not detected | Verify ROCm installation and device plugin |

### **Deployment Issues**

| Issue | Solution |
|-------|----------|
| Pod stuck in Pending | Check resource availability and node labels |
| Image pull fails | Verify image exists in local registry |
| Container crashes | Check logs and resource limits |
| Service not accessible | Verify NodePort and firewall rules |

### **Performance Issues**

| Issue | Solution |
|-------|----------|
| Slow model loading | Increase memory limits and disable probes |
| GPU underutilization | Check tensor parallelism settings |
| High memory usage | Optimize model precision and batch size |
| Network latency | Use local registry and optimize CNI |

## **Support and Resources**

- **Documentation**: See `docs/` directory
- **Examples**: See `examples/` directory
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **API Reference**: See `docs/API.md`

For issues and questions, check the troubleshooting guide or create an issue in the repository. 