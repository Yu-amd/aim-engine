# AIM Engine

**Kubernetes Operator for AMD Inference Microservices**

AIM Engine is a Kubernetes operator that manages the lifecycle of AIMs (AMD Inference Microservices) - AI model deployments with optimal configurations and built-in caching for AMD hardware.

## **What AIM Engine Does**

- **Declarative Management**: Define AIM deployments using Kubernetes custom resources
- **Auto Recipe Selection**: Automatically selects optimal configurations for AMD GPUs
- **Built-in Caching**: Manages persistent volumes for model caching
- **Lifecycle Management**: Handles deployment, scaling, and cleanup of AIMs
- **Production Ready**: Health checks, monitoring, and error handling
- **Multi-Model Support**: Manage multiple AIM instances simultaneously

## **Recent Improvements**

- **Optimized Operator Performance**: Efficient reconciliation and resource management
- **Enhanced Caching**: Improved persistent volume management for model caching
- **Better Scalability**: Operator performance doesn't degrade with more AIM instances
- **Robust Error Handling**: Comprehensive error recovery and status reporting

## **Quick Start**

### **Prerequisites**
- Kubernetes cluster (1.28+)
- AMD GPU with ROCm support (MI300X, MI325X, etc.)
- Docker installed and running
- At least 16GB RAM (32GB+ recommended for large models)

### **Installation**
```bash
# Clone the repository
git clone <repository-url>
cd aim-engine

# Deploy the AIM Engine operator
cd k8s/operator
./scripts/setup-and-test-operator.sh
```

### **Basic Usage**
```bash
# Create an AIM recipe
kubectl apply -f k8s/operator/examples/aimrecipe.yaml

# Deploy an AIM instance
kubectl apply -f k8s/operator/examples/aimendpoint.yaml

# Check AIM status
kubectl get aimendpoint -n aim-engine

# Access the AIM service
kubectl get svc -n aim-engine
```

### **Testing Your AIM**
Once your AIM is running, verify it's ready for inference:

```bash
# Get the service port
kubectl get svc <aim-name> -n aim-engine

# Test if the AIM is responding
curl -f http://localhost:<port>/health

# Test if models are loaded and ready
curl -f http://localhost:<port>/v1/models

# Test a simple inference request
curl -X POST http://localhost:<port>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

**Expected responses:**
- **Health endpoint**: Returns HTTP 200 (empty response)
- **Models endpoint**: Returns JSON with available models
- **Chat endpoint**: Returns JSON with generated text

If all tests pass, your AIM is ready for use with agent examples and other applications!

### **Production Deployment**
```bash
# Deploy AIM Engine operator to production cluster
cd k8s/operator
./scripts/setup-and-test-operator.sh

# Create production AIM recipes
kubectl apply -f production-recipes/

# Deploy production AIM instances
kubectl apply -f production-endpoints/

# Monitor AIM health
kubectl get aimendpoint -n aim-engine -w
```

## **Kubernetes Cluster Setup**

### **Quick Setup (Complete Cluster)**
```bash
# Set up complete Kubernetes cluster with AMD GPU support
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

> **⚠️ Known Issue**: On fresh remote nodes, the setup script may fail at Step 4 with a Docker permission error. This is a known issue with Docker group membership not being inherited by the current shell session. **Solution**: Simply run the script a second time - it will work on the second run because the new shell session will have the proper Docker group membership.
>
> **Error Message**: `Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?`
>
> **Workaround**: 
> ```bash
> # First run (may fail)
> sudo ./k8s/scripts/setup-complete-kubernetes.sh
> 
> # Second run (will work)
> sudo ./k8s/scripts/setup-complete-kubernetes.sh
> ```
>
> This issue is being addressed in future versions. For now, running the script twice is the recommended workaround.

### **Deploy AIM to Existing Cluster**
```bash
# Deploy AIM Engine operator
cd k8s/operator
./scripts/setup-and-test-operator.sh

# Deploy AIM instances
kubectl apply -f examples/aimrecipe.yaml
kubectl apply -f examples/aimendpoint.yaml

# Deploy with custom configuration
kubectl apply -f custom-aim-config.yaml
```

## **AIM Engine Operator**

The AIM Engine Kubernetes Operator provides declarative management of AIM (AMD Inference Microservice) deployments using custom resources.

### **Operator Features**
- **Declarative Management**: Define AIM deployments using YAML
- **Auto Recipe Selection**: Automatically select optimal configurations
- **Built-in Caching**: Persistent volume management for model caching
- **Scaling**: Horizontal Pod Autoscaler support
- **Monitoring**: Integrated metrics and health checks
- **Multi-Model Support**: Manage multiple AIM instances simultaneously

### **Custom Resources**
- **AIMRecipe**: Define model configurations and hardware requirements
- **AIMEndpoint**: Deploy and manage AIM instances
- **AIMCache**: Configure persistent caching for models

### **Deploy the Operator**

#### **Option 1: Complete Setup (Recommended)**
```bash
# Deploy operator with comprehensive testing
cd k8s/operator
chmod +x scripts/setup-and-test-operator.sh
./scripts/setup-and-test-operator.sh
```

#### **Option 2: Manual Deployment**
```bash
# Build and deploy operator manually
cd k8s/operator

# Build operator binary
go build -o manager cmd/operator/main.go

# Build Docker image
docker build -t localhost:5000/aim-engine-operator:latest .

# Push to local registry
docker push localhost:5000/aim-engine-operator:latest

# Deploy to Kubernetes
kubectl create namespace aim-engine-system
kubectl apply -f config/crd/bases/
kubectl apply -f config/rbac/
kubectl apply -f config/manager/

# Wait for operator to be ready
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n aim-engine-system --timeout=300s
```

### **Validate Operator Deployment**
```bash
# Check operator status
kubectl get pods -n aim-engine-system

# Verify CRDs are installed
kubectl get crd | grep aim.engine.amd.com

# Check operator logs
kubectl logs -n aim-engine-system -l control-plane=controller-manager --tail=20
```

### **Test the Operator**

#### **Quick Test**
```bash
# Run comprehensive test suite
cd k8s/operator
./scripts/test-operator.sh
```

#### **Manual Testing**
```bash
# Create a test recipe
kubectl apply -f examples/aimrecipe.yaml

# Create a test endpoint
kubectl apply -f examples/aimendpoint.yaml

# Check status
kubectl get aimrecipe -n aim-engine
kubectl get aimendpoint -n aim-engine

# Monitor reconciliation
kubectl logs -n aim-engine-system -l control-plane=controller-manager --tail=10 -f
```

### **Using the Operator**

#### **Create an AIMRecipe**
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMRecipe
metadata:
  name: qwen-7b-recipe
  namespace: aim-engine
spec:
  modelId: "Qwen/Qwen2.5-7B-Instruct"
  backend: "vllm"
  hardware: "MI300X"
  precision: "bfloat16"
  description: "Qwen2.5-7B-Instruct model recipe"
  configurations:
    - gpuCount: 1
      enabled: true
      resources:
        requests:
          cpu: "4"
          memory: "16Gi"
          amd.com/gpu: "1"
        limits:
          cpu: "8"
          memory: "32Gi"
          amd.com/gpu: "1"
      env:
        - name: VLLM_USE_ROCM
          value: "1"
        - name: PYTORCH_ROCM_ARCH
          value: "gfx90a"
```

#### **Create an AIMEndpoint**
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: my-aim-instance
  namespace: aim-engine
spec:
  model:
    id: "Qwen/Qwen2.5-7B-Instruct"
    version: "latest"
  recipe:
    autoSelect: true
    gpuCount: 1
  resources:
    cpu: "4"
    memory: "16Gi"
    gpuCount: 1
    cpuLimit: "8"
    memoryLimit: "32Gi"
  scaling:
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilization: 70
  cache:
    enabled: true
  service:
    type: "NodePort"
    port: 8000
    targetPort: 8000
```

#### **Monitor and Manage**
```bash
# List all AIM instances
kubectl get aimendpoint -n aim-engine

# Get detailed status
kubectl describe aimendpoint my-aim-instance -n aim-engine

# Check pod status
kubectl get pods -n aim-engine -l app.kubernetes.io/name=aim-endpoint

# Access the service
kubectl get svc my-aim-instance -n aim-engine

# Test the AIM
curl http://localhost:8000/health
```

### **Operator Cleanup**
```bash
# Remove custom resources
kubectl delete aimendpoint --all -n aim-engine
kubectl delete aimrecipe --all -n aim-engine

# Uninstall operator
kubectl delete -f config/manager/
kubectl delete -f config/rbac/
kubectl delete -f config/crd/bases/
kubectl delete namespace aim-engine-system
```

## **Examples**

### **Running Examples**
```bash
cd examples

# Use the quick start script (recommended)
./quick_start.sh

# Or run individual examples
python3 simple_agent.py      # Basic chat agent
python3 advanced_agent.py    # Agent with tools
python3 web_agent.py         # Web interface
```

### **Available Examples**
- **Simple Agent**: Basic conversational agent with streaming responses
- **Advanced Agent**: Agent with tools, memory, and structured reasoning
- **Web Agent**: Modern web interface with real-time chat
- **Test Scripts**: Various testing and diagnostic tools

See `examples/README.md` for detailed information about each example.

## **Cleanup**

### **Docker Cleanup (Single-Node Deployment)**

#### **Using the Cleanup Script (Recommended)**
```bash
# Basic cleanup (stops and removes containers only)
./scripts/cleanup-docker.sh

# Remove containers and images
./scripts/cleanup-docker.sh --images

# Nuclear option: Remove everything
./scripts/cleanup-docker.sh --all
```

#### **Manual Cleanup Commands**
```bash
# Stop all running AIM containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop

# Remove all AIM containers (any state)
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Remove AIM images
docker rmi aim-vllm:latest --force

# Clean up dangling resources
docker system prune -f
```

### **Kubernetes Cleanup (Cluster Deployment)**

#### **Using the Cleanup Script (Recommended)**
```bash
# Basic cleanup (removes Kubernetes resources only)
sudo ./k8s/scripts/cleanup-kubernetes.sh

# Remove Kubernetes resources and Docker images
sudo ./k8s/scripts/cleanup-kubernetes.sh --images

# Remove everything including local registry
sudo ./k8s/scripts/cleanup-kubernetes.sh --registry

# Nuclear option: Remove entire cluster
sudo ./k8s/scripts/cleanup-kubernetes.sh --cluster

# Complete cleanup (everything)
sudo ./k8s/scripts/cleanup-kubernetes.sh --all
```

#### **Manual Kubernetes Cleanup**
```bash
# Remove AIM instances
kubectl delete aimendpoint --all -n aim-engine

# Remove AIM Engine operator
kubectl delete -f k8s/operator/config/manager/
kubectl delete -f k8s/operator/config/rbac/
kubectl delete -f k8s/operator/config/crd/bases/

# Remove namespace
kubectl delete namespace aim-engine

# Remove local registry
docker stop local-registry
docker rm local-registry

# Remove images from registry
docker rmi localhost:5000/aim-vllm:latest
docker rmi aim-vllm:latest
```

### **Quick Cleanup Commands**
```bash
# Docker: Stop and remove all AIM containers
docker ps -q --filter "ancestor=aim-vllm:latest" | xargs -r docker stop && \
docker ps -aq --filter "ancestor=aim-vllm:latest" | xargs -r docker rm -f

# Kubernetes: Remove AIM resources
kubectl delete all -n aim-engine --all
kubectl delete namespace aim-engine

# Nuclear option: Stop and remove ALL containers (use with caution)
docker ps -q | xargs -r docker stop && docker ps -aq | xargs -r docker rm -f
```

## **Troubleshooting**

### **Common Issues**

#### **Docker Permission Error on Fresh Remote Nodes**
**Problem**: Setup script fails with `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`

**Cause**: Docker group membership not inherited by current shell session

**Solution**: Run the setup script twice:
```bash
# First run (may fail)
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Second run (will work)
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

#### **GPU Not Detected**
**Problem**: AMD GPU not recognized by Kubernetes

**Solution**: 
```bash
# Check GPU status
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Verify AMD GPU device plugin
kubectl get pods -n kube-system | grep amd

# Reinstall GPU device plugin if needed
kubectl delete daemonset amd-gpu-device-plugin -n kube-system
kubectl apply -f k8s/amd-gpu-device-plugin.yaml
```

#### **AIM Pod Stuck in Pending**
**Problem**: AIM pod cannot be scheduled

**Solution**:
```bash
# Check pod events
kubectl describe pod -n aim-engine

# Check node resources
kubectl describe node

# Check if GPU resources are available
kubectl get nodes -o json | jq '.items[].status.allocatable."amd.com/gpu"'
```

#### **Operator Pod Stuck in Pending**
**Problem**: Operator pod cannot be scheduled

**Solution**:
```bash
# Check operator pod events
kubectl describe pod -n aim-engine-system -l control-plane=controller-manager

# Check if tolerations are applied
kubectl get deployment aim-engine-operator-controller-manager -n aim-engine-system -o yaml | grep -A 10 tolerations

# Check RBAC permissions
kubectl auth can-i create deployments --as=system:serviceaccount:aim-engine-system:aim-engine-operator-controller-manager
```

#### **Custom Resources Not Reconciling**
**Problem**: AIMEndpoint or AIMRecipe not being processed

**Solution**:
```bash
# Check operator logs
kubectl logs -n aim-engine-system -l control-plane=controller-manager --tail=50

# Check CRD status
kubectl get crd aimendpoints.aim.engine.amd.com -o yaml

# Check custom resource status
kubectl describe aimendpoint <name> -n aim-engine
kubectl describe aimrecipe <name> -n aim-engine
```

#### **Volume Duplication Error**
**Problem**: `Duplicate value: "model-cache"` error in operator logs

**Solution**:
```bash
# Delete the problematic deployment
kubectl delete deployment <name> -n aim-engine

# Restart the operator
kubectl rollout restart deployment aim-engine-operator-controller-manager -n aim-engine-system

# Recreate the custom resource
kubectl apply -f examples/aimendpoint.yaml
```

## **Quick Reference**

### **Operator Commands**
```bash
# Check operator status
kubectl get pods -n aim-engine-system

# View operator logs
kubectl logs -n aim-engine-system -l control-plane=controller-manager -f

# List custom resources
kubectl get aimendpoint -n aim-engine
kubectl get aimrecipe -n aim-engine
kubectl get aimcache -n aim-engine

# Get detailed resource info
kubectl describe aimendpoint <name> -n aim-engine
kubectl describe aimrecipe <name> -n aim-engine

# Check CRDs
kubectl get crd | grep aim.engine.amd.com

# Restart operator
kubectl rollout restart deployment aim-engine-operator-controller-manager -n aim-engine-system
```

### **Common Workflows**
```bash
# Deploy a new AIM
kubectl apply -f examples/aimrecipe.yaml
kubectl apply -f examples/aimendpoint.yaml

# Scale an AIM
kubectl patch aimendpoint <name> -n aim-engine -p '{"spec":{"scaling":{"minReplicas":2}}}'

# Enable caching
kubectl patch aimendpoint <name> -n aim-engine -p '{"spec":{"cache":{"enabled":true}}}'

# Check AIM health
kubectl get svc <name> -n aim-engine
curl http://localhost:8000/health
```

## **Documentation**

- **Architecture**: See `docs/ARCHITECTURE.md`
- **API Reference**: See `docs/API.md`
- **Recipe System**: See `docs/RECIPE_GUIDE.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Docker Deployment**: See `docker/docs/`
- **Kubernetes Deployment**: See `k8s/docs/`
- **Operator Development**: See `k8s/operator/README.md`
