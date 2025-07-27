# AMD GPU Setup for Kubernetes

## Prerequisites

### 1. Hardware Requirements
- AMD GPU with ROCm support (MI200, MI300, RX 6000+, etc.)
- Linux kernel with ROCm support
- ROCm drivers installed on host

### 2. Install AMD GPU Device Plugin

```bash
# Install the AMD GPU device plugin
kubectl create -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Verify installation
kubectl get pods -n kube-system | grep amdgpu
kubectl describe nodes | grep -A 10 "amd.com/gpu"
```

### 3. Verify GPU Detection

```bash
# Check for GPU nodes
kubectl get nodes -l amd.com/gpu=true

# Test GPU allocation
kubectl run gpu-test --image=rocm/dev-ubuntu-20.04 --rm -it --restart=Never -- \
  bash -c "rocm-smi"
```

## Production Deployment

### 1. Use Full GPU-Enabled Deployment

```bash
# Apply the production deployment with GPU support
kubectl apply -f k8s/deployment.yaml
```

### 2. GPU Resource Configuration

The production deployment includes:

```yaml
resources:
  requests:
    amd.com/gpu: "4"  # Request 4 AMD GPUs
  limits:
    amd.com/gpu: "4"  # Limit to 4 AMD GPUs
```

### 3. GPU Device Mounts

```yaml
volumeMounts:
- name: kfd-device
  mountPath: /dev/kfd
- name: dri-device
  mountPath: /dev/dri

volumes:
- name: kfd-device
  hostPath:
    path: /dev/kfd
- name: dri-device
  hostPath:
    path: /dev/dri
```

## Testing GPU Access

### 1. Check GPU Allocation

```bash
# Check if pods have GPU access
kubectl describe pod <pod-name> -n aim-engine

# Look for GPU allocation in the output
```

### 2. Test GPU Inside Container

```bash
# Execute into the pod
kubectl exec -it deployment/aim-engine -n aim-engine -- bash

# Test GPU access
rocm-smi
rocm-smi
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}')"
```

### 3. Monitor GPU Usage

```bash
# Check GPU metrics
kubectl top pods -n aim-engine

# Monitor GPU utilization
kubectl exec -it deployment/aim-engine -n aim-engine -- rocm-smi
```

## Troubleshooting

### Common Issues

1. **GPU not detected**
   ```bash
   # Check if ROCm is installed on host
   rocm-smi
   
   # Check kernel modules
   lsmod | grep amdgpu
   ```

2. **Permission issues**
   ```bash
   # Check device permissions
   ls -la /dev/kfd
   ls -la /dev/dri
   
   # Add user to video group
   sudo usermod -a -G video $USER
   ```

3. **Device plugin not working**
   ```bash
   # Check device plugin logs
   kubectl logs -n kube-system -l app=amdgpu-dp
   
   # Restart device plugin
   kubectl delete pod -n kube-system -l app=amdgpu-dp
   ```

## Performance Optimization

### 1. GPU Memory Configuration

```yaml
env:
- name: PYTORCH_CUDA_ALLOC_CONF
  value: "max_split_size_mb:512"
- name: HIP_VISIBLE_DEVICES
  value: "0,1,2,3"
```

### 2. Multi-GPU Configuration

```yaml
resources:
  requests:
    amd.com/gpu: "8"  # Use all available GPUs
  limits:
    amd.com/gpu: "8"
```

### 3. Model Loading Optimization

```yaml
env:
- name: VLLM_USE_ROCM
  value: "1"
- name: PYTORCH_ROCM_ARCH
  value: "gfx90a"  # Adjust for your GPU architecture
``` 
