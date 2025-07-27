# AIM Engine Cleanup Guide

This guide covers how to properly stop and remove all AIM Engine resources for both Docker and Kubernetes deployments.

## **Quick Reference**

### **Docker Cleanup (Single-Node)**
```bash
# Basic cleanup
./scripts/cleanup-docker.sh

# Remove images too
./scripts/cleanup-docker.sh --images

# Nuclear option
./scripts/cleanup-docker.sh --all
```

### **Kubernetes Cleanup (Cluster)**
```bash
# Basic cleanup
sudo ./k8s/scripts/cleanup-kubernetes.sh

# Remove images and registry
sudo ./k8s/scripts/cleanup-kubernetes.sh --images --registry

# Remove entire cluster
sudo ./k8s/scripts/cleanup-kubernetes.sh --cluster

# Complete cleanup
sudo ./k8s/scripts/cleanup-kubernetes.sh --all
```

## **Docker Cleanup (Single-Node Deployment)**

### **Using the Cleanup Script (Recommended)**

The `scripts/cleanup-docker.sh` script provides safe and comprehensive cleanup:

```bash
# Basic cleanup - stops and removes containers only
./scripts/cleanup-docker.sh

# Remove containers and AIM Engine images
./scripts/cleanup-docker.sh --images

# Nuclear option - removes everything (all containers, images, volumes, networks)
./scripts/cleanup-docker.sh --all
```

### **Manual Cleanup Commands**

If you prefer manual cleanup or need to target specific resources:

#### **Stop Running Containers**
```bash
# Stop all running AIM Engine containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop

# Stop by container name (if you named them)
docker stop aim-engine 2>/dev/null || echo "Container not found"
docker stop nice_montalcini 2>/dev/null || echo "Container not found"
```

#### **Remove Containers**
```bash
# Remove all AIM Engine containers (any state)
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Remove by container name
docker rm -f aim-engine 2>/dev/null || echo "Container not found"
```

#### **Remove Images**
```bash
# Remove AIM Engine images
docker rmi aim-vllm:latest --force

# Remove all AIM Engine related images
docker images | grep aim-vllm | awk '{print $3}' | xargs -r docker rmi --force
```

#### **Clean Up System Resources**
```bash
# Remove dangling images, containers, networks
docker system prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f
```

### **One-Liner Commands**

```bash
# Stop and remove all AIM Engine containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop && \
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Nuclear option: Stop and remove ALL containers (use with caution)
docker ps -q | xargs -r docker stop && docker ps -aq | xargs -r docker rm -f
```

## **Kubernetes Cleanup (Cluster Deployment)**

### **Using the Cleanup Script (Recommended)**

The `k8s/scripts/cleanup-kubernetes.sh` script handles all Kubernetes cleanup scenarios:

```bash
# Basic cleanup - removes Kubernetes resources only
sudo ./k8s/scripts/cleanup-kubernetes.sh

# Remove Kubernetes resources and Docker images
sudo ./k8s/scripts/cleanup-kubernetes.sh --images

# Remove everything including local registry
sudo ./k8s/scripts/cleanup-kubernetes.sh --registry

# Remove entire Kubernetes cluster
sudo ./k8s/scripts/cleanup-kubernetes.sh --cluster

# Complete cleanup - everything
sudo ./k8s/scripts/cleanup-kubernetes.sh --all
```

### **Manual Kubernetes Cleanup**

#### **Remove AIM Engine Deployment**
```bash
# Uninstall Helm release
helm uninstall aim-engine -n aim-engine

# Or remove resources directly
kubectl delete deployment aim-engine -n aim-engine
kubectl delete service aim-engine-service -n aim-engine
kubectl delete pvc aim-engine-pvc -n aim-engine
kubectl delete serviceaccount aim-engine -n aim-engine
```

#### **Remove Namespace**
```bash
# Remove the entire namespace (removes all resources)
kubectl delete namespace aim-engine

# Wait for namespace deletion
kubectl wait --for=delete namespace/aim-engine --timeout=60s
```

#### **Clean Up Local Registry**
```bash
# Stop and remove registry container
docker stop local-registry
docker rm local-registry

# Remove registry images
docker rmi localhost:5000/aim-vllm:latest
docker rmi registry:2
```

#### **Remove GPU Resources**
```bash
# Remove AMD GPU device plugin
kubectl delete daemonset amd-gpu-device-plugin -n kube-system

# Remove GPU labels from nodes
kubectl label node $(hostname) amd.com/gpu- || true
```

### **Cluster-Level Cleanup**

#### **Reset Kubernetes Cluster**
```bash
# Drain the node
kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data --force

# Reset kubeadm
kubeadm reset --force

# Remove kubeconfig files
rm -rf $HOME/.kube
rm -rf /home/*/.kube

# Clean containerd data
rm -rf /var/lib/containerd/io.containerd.grpc.v1.cri/sandboxes/*
rm -rf /var/lib/containerd/io.containerd.grpc.v1.cri/containers/*

# Restart containerd
systemctl restart containerd
```

## **Troubleshooting Cleanup Issues**

### **Common Problems and Solutions**

#### **Container Won't Stop**
```bash
# Force stop with SIGKILL
docker kill <container-id>

# Or stop all containers forcefully
docker ps -q | xargs -r docker kill
```

#### **Namespace Won't Delete**
```bash
# Check for finalizers
kubectl get namespace aim-engine -o yaml

# Remove finalizers
kubectl patch namespace aim-engine -p '{"metadata":{"finalizers":[]}}' --type=merge
```

#### **Helm Release Won't Uninstall**
```bash
# Force uninstall
helm uninstall aim-engine -n aim-engine --no-hooks

# Or delete resources manually
kubectl delete all -n aim-engine --all
kubectl delete namespace aim-engine
```

#### **Registry Won't Stop**
```bash
# Force stop registry
docker kill local-registry
docker rm -f local-registry

# Check for other registry containers
docker ps | grep registry
```

### **Verification Commands**

After cleanup, verify everything is removed:

```bash
# Check for remaining containers
docker ps -a | grep aim

# Check for remaining images
docker images | grep aim

# Check for remaining Kubernetes resources
kubectl get all -n aim-engine 2>/dev/null || echo "Namespace not found"

# Check for remaining namespaces
kubectl get namespaces | grep aim

# Check for remaining Helm releases
helm list -n aim-engine
```

## **Best Practices**

### **Before Cleanup**
1. **Save Important Data**: Ensure any important model cache or data is backed up
2. **Check Dependencies**: Verify no other services depend on AIM Engine
3. **Document Configuration**: Note any custom configurations for re-deployment

### **During Cleanup**
1. **Use Scripts**: Prefer the provided cleanup scripts over manual commands
2. **Check Dependencies**: Ensure cleanup doesn't affect other services
3. **Verify Removal**: Use verification commands to confirm cleanup

### **After Cleanup**
1. **Verify System State**: Ensure system resources are properly freed
2. **Check Logs**: Review logs for any cleanup errors
3. **Test Redeployment**: Verify you can redeploy if needed

## **Recovery After Cleanup**

### **Quick Redeployment**
```bash
# Docker: Rebuild and deploy
./scripts/build-aim-vllm.sh
docker run --rm -it --device=/dev/kfd --device=/dev/dri --group-add=video --group-add=render -p 8000:8000 aim-vllm:latest aim-shell

# Kubernetes: Redeploy
sudo ./k8s/scripts/deploy-aim-engine.sh
```

### **Full Recovery**
```bash
# Complete cluster setup
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

## **Summary**

- **Use cleanup scripts** for safe and comprehensive cleanup
- **Verify cleanup** with provided verification commands
- **Document custom configurations** before cleanup
- **Test redeployment** after cleanup to ensure system integrity

The cleanup scripts handle all edge cases and provide safe, comprehensive cleanup for both Docker and Kubernetes deployments. 