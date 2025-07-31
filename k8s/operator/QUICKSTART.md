# AIM Engine Kubernetes Operator - Quick Start

This guide will help you quickly deploy and use the AIM Engine Kubernetes Operator.

## Prerequisites

- Kubernetes cluster 1.24+
- AMD GPU nodes with ROCm support
- kubectl configured
- Docker installed
- Local container registry (or modify image references)

## Quick Installation

1. **Clone and navigate to the operator directory:**
   ```bash
   cd k8s/operator
   ```

2. **Run the installation script:**
   ```bash
   ./scripts/install.sh
   ```

3. **Verify installation:**
   ```bash
   kubectl get pods -n aim-engine-operator
   kubectl get crd | grep aim.engine.amd.com
   ```

## Deploy Your First AIM Endpoint

1. **Create a recipe (optional - operator can auto-select):**
   ```bash
   kubectl apply -f examples/aimrecipe-example.yaml
   ```

2. **Create a cache (optional):**
   ```bash
   kubectl apply -f examples/aimcache-example.yaml
   ```

3. **Deploy an endpoint:**
   ```bash
   kubectl apply -f examples/aimendpoint-example.yaml
   ```

4. **Monitor the deployment:**
   ```bash
   kubectl get aimendpoints -n aim-engine
   kubectl describe aimendpoint qwen-32b-production -n aim-engine
   ```

## Basic Usage Examples

### Simple Endpoint Deployment

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen-7b-demo
  namespace: aim-engine
spec:
  model:
    id: "Qwen/Qwen2.5-7B-Instruct"
  recipe:
    autoSelect: true
  service:
    type: NodePort
```

### Production Endpoint with Custom Configuration

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen-32b-production
  namespace: aim-engine
spec:
  model:
    id: "Qwen/Qwen3-32B"
  recipe:
    autoSelect: false
    gpuCount: 4
    precision: "bfloat16"
    backend: "vllm"
  scaling:
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilization: 70
  service:
    type: LoadBalancer
  monitoring:
    enabled: true
```

## Monitoring and Troubleshooting

### Check Operator Status
```bash
# Check operator logs
kubectl logs -f deployment/aim-engine-operator-controller-manager -n aim-engine-operator

# Check endpoint status
kubectl get aimendpoints -n aim-engine -o wide

# Check created resources
kubectl get all -n aim-engine -l app.kubernetes.io/name=aim-endpoint
```

### Common Issues

1. **GPU Not Available:**
   ```bash
   # Check GPU device plugin
   kubectl get pods -n kube-system | grep amd-gpu-device-plugin
   
   # Check node labels
   kubectl get nodes --show-labels | grep amd.com/gpu
   ```

2. **Image Pull Issues:**
   ```bash
   # Check pod events
   kubectl describe pod -l app.kubernetes.io/name=aim-endpoint -n aim-engine
   ```

3. **Recipe Selection Failed:**
   ```bash
   # Check available recipes
   kubectl get aimrecipe -n aim-engine
   ```

## Advanced Features

### Custom Recipe Definition

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMRecipe
metadata:
  name: custom-recipe
  namespace: aim-engine
spec:
  modelId: "Qwen/Qwen3-32B"
  hardware: "MI300X"
  precision: "bfloat16"
  backend: "vllm"
  configurations:
    - gpuCount: 4
      enabled: true
      args:
        - "--model"
        - "Qwen/Qwen3-32B"
        - "--dtype"
        - "bfloat16"
        - "--tensor-parallel-size"
        - "4"
      resources:
        requests:
          amd.com/gpu: "4"
          memory: "64Gi"
          cpu: "16"
```

### Model Caching

```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMCache
metadata:
  name: model-cache
  namespace: aim-engine
spec:
  storage:
    size: "500Gi"
    storageClass: "fast-ssd"
  models:
    - id: "Qwen/Qwen3-32B"
      priority: "high"
      retention: "30d"
  cleanup:
    enabled: true
    schedule: "0 2 * * *"
```

## Uninstallation

To remove the operator:

```bash
# Delete custom resources
kubectl delete aimendpoints --all -n aim-engine
kubectl delete aimrecipes --all -n aim-engine
kubectl delete aimcaches --all -n aim-engine

# Delete operator
kubectl delete -f config/manager/
kubectl delete -f config/rbac/
kubectl delete -f config/crd/bases/

# Delete namespaces
kubectl delete namespace aim-engine-operator
kubectl delete namespace aim-engine
```

## Next Steps

- Read the [full documentation](README.md) for detailed configuration options
- Explore [examples](examples/) for more use cases
- Check [troubleshooting guide](TROUBLESHOOTING.md) for common issues
- Join the community for support and contributions 