# AIM Engine Development Guide - Minikube Deployment

## **Overview**

This comprehensive guide provides everything you need to deploy and test AIM Engine in Minikube for development, testing, and learning purposes. Minikube provides a lightweight Kubernetes environment perfect for development without requiring GPU hardware.

## **Features**

### **Recipe Selection**
- **Automatic recipe selection** based on model and resources
- **Mock recipe configuration** for development testing
- **Recipe validation** and fallback mechanisms
- **Configuration overrides** support

### **Monitoring & Observability**
- **Prometheus metrics** endpoint (`/metrics`)
- **Health checks** endpoint (`/health`)
- **Recipe information** endpoint (`/recipe`)
- **ServiceMonitor** for Prometheus integration
- **Basic Grafana dashboard** configuration

### **Development Features**
- **Mock vLLM server** with recipe-aware responses
- **TGI server** for real inference capabilities
- **Comprehensive logging** and debugging
- **Resource optimization** for Minikube constraints
- **Easy testing** with included test scripts

## **Prerequisites**

### **Software Requirements**
- Minikube installed
- kubectl configured
- Docker installed
- jq (for JSON parsing)

### **System Requirements**
- 4GB RAM minimum (8GB recommended)
- 20GB disk space
- Docker driver support

### **Installation**
```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install jq (for JSON parsing)
sudo apt-get install jq
```

### **Check Prerequisites**
```bash
# Check Minikube
minikube version

# Check kubectl
kubectl version --client

# Check Docker
docker --version

# Check jq
jq --version
```

## **Deployment Options**

### **Option 1: Mock Server (Default)**
**Use Case**: Quick testing, recipe validation, no GPU required
**Startup Time**: Fast (< 1 minute)
**Resource Usage**: Low

### **Option 2: TGI Server (Real Inference)**
**Use Case**: Real inference testing, API validation
**Startup Time**: Medium (2-5 minutes for model download)
**Resource Usage**: Medium

## **Quick Start**

### **Step 1: Start Minikube**
```bash
# Start Minikube with sufficient resources
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable storage-provisioner
minikube addons enable metrics-server
```

### **Step 2: Deploy AIM Engine**

#### **Deploy Mock Server (Default)**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with mock server
./deploy.sh
```

#### **Deploy TGI Server (Real Inference)**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with TGI for real inference
./deploy.sh tgi
```

### **Step 3: Test the Deployment**
```bash
# Test mock server functionality
./test-recipe.sh

# Test TGI inference (if deployed with TGI)
./test-tgi.sh
```

## **Configuration**

### **Recipe Configuration**

The deployment automatically selects a recipe based on the deployment mode:

#### **Mock Server Configuration**
```yaml
# Default recipe for Minikube mock server
recipe_id: qwen3-32b-1gpu-bf16
model_id: Qwen/Qwen3-32B
gpu_count: 1
precision: bf16
backend: vllm
```

#### **TGI Server Configuration**
```yaml
# Default recipe for Minikube TGI server
recipe_id: dialogpt-medium-1gpu-float16
model_id: microsoft/DialoGPT-medium
gpu_count: 1
precision: float16
backend: tgi
```

### **Custom Recipe Selection**

You can customize the recipe by modifying the environment variables in `recipe-selector-job.yaml`:

```yaml
env:
- name: MODEL_ID
  value: "microsoft/DialoGPT-medium"  # Change model
- name: GPU_COUNT
  value: "1"                          # Change GPU count
- name: PRECISION
  value: "float16"                    # Change precision
- name: BACKEND
  value: "tgi"                        # Change backend
```

## **Available Endpoints**

### **Mock Server Endpoints**
| Endpoint | Description | Example |
|----------|-------------|---------|
| `/` | Main web interface | Shows recipe configuration |
| `/metrics` | Prometheus metrics | Recipe and performance metrics |
| `/health` | Health check | JSON health status |
| `/recipe` | Recipe information | Detailed recipe configuration |

### **TGI Server Endpoints**
| Endpoint | Description | Example |
|----------|-------------|---------|
| `/health` | Health check | JSON health status |
| `/info` | Model information | Model details and configuration |
| `/generate` | Text generation | POST with input text and parameters |
| `/metrics` | Prometheus metrics | Performance and usage metrics |

## 🌐 **Accessing Services**

### **Port Forward Method**
```bash
# Port forward to access endpoints
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Mock Server Endpoints
curl http://localhost:8000/                    # Web interface
curl http://localhost:8000/metrics             # Metrics
curl http://localhost:8000/health              # Health check
curl http://localhost:8000/recipe              # Recipe info

# TGI Server Endpoints
curl http://localhost:8000/health              # Health check
curl http://localhost:8000/info                # Model info
curl -X POST http://localhost:8000/generate \  # Text generation
  -H "Content-Type: application/json" \
  -d '{"inputs": "Hello", "parameters": {"max_new_tokens": 50}}'
```

### **Minikube Service Method**
```bash
# Access via Minikube service
minikube service aim-engine-service -n aim-engine
```

## **Testing**

### **Automated Testing**

#### **Test Mock Server**
```bash
# Run automated tests
./test-recipe.sh

# Expected output:
# Testing AIM Engine recipe functionality in Minikube...
# Checking deployment status...
# Deployment is running
# Testing recipe configuration...
# Recipe configuration found
# Testing mock server endpoints...
# Mock server responding correctly
# Testing monitoring endpoints...
# Monitoring endpoints working
# All tests passed! AIM Engine recipe functionality is working in Minikube.
```

#### **Test TGI Server**
```bash
# Run TGI-specific tests
./test-tgi.sh

# Expected output:
# Testing AIM Engine TGI functionality in Minikube...
# Checking deployment status...
# Deployment is running
# Testing TGI health endpoint...
# TGI health endpoint responding
# Testing TGI inference endpoint...
# TGI inference working
# All TGI tests passed!
```

### **Manual Testing**

#### **Test Recipe Endpoint**
```bash
# Port forward to service
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Test recipe endpoint
curl http://localhost:8000/recipe

# Expected response:
{
  "recipe_id": "dialogpt-medium-1gpu-float16",
  "model_id": "microsoft/DialoGPT-medium",
  "gpu_count": 1,
  "precision": "float16",
  "backend": "tgi",
  "hardware": "CPU",
  "performance": {
    "expected_tokens_per_second": 50,
    "expected_latency_ms": 200
  }
}
```

#### **Test Metrics Endpoint**
```bash
# Test metrics endpoint
curl http://localhost:8000/metrics

# Expected metrics:
# aim_recipe_selection_total{recipe_id="dialogpt-medium-1gpu-float16"} 1
# aim_performance_tokens_per_second{recipe_id="dialogpt-medium-1gpu-float16"} 50
# aim_gpu_memory_utilization{recipe_id="dialogpt-medium-1gpu-float16"} 0.0
```

#### **Test Health Endpoint**
```bash
# Test health endpoint
curl http://localhost:8000/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "recipe_id": "dialogpt-medium-1gpu-float16"
}
```

## **Verification Steps**

### **Check Deployment Status**
```bash
# Check if pods are running
kubectl get pods -n aim-engine

# Expected output:
NAME                           READY   STATUS    RESTARTS   AGE
aim-engine-6d4cf56db-abc12    1/1     Running   0          2m

# Check deployment status
kubectl get deployment -n aim-engine

# Expected output:
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
aim-engine   1/1     1            1           2m
```

### **Check Recipe Configuration**
```bash
# Check recipe selector job
kubectl get jobs -n aim-engine

# Expected output:
NAME                           COMPLETIONS   DURATION   AGE
aim-engine-recipe-selector     1/1           30s        2m

# Check recipe configuration
kubectl get configmap -n aim-engine aim-engine-recipe-config -o yaml

# Expected content:
apiVersion: v1
kind: ConfigMap
metadata:
  name: aim-engine-recipe-config
data:
  RECIPE_ID: "dialogpt-medium-1gpu-float16"
  MODEL_ID: "microsoft/DialoGPT-medium"
  GPU_COUNT: "1"
  PRECISION: "float16"
  BACKEND: "tgi"
```

### **Check Service Access**
```bash
# Check service
kubectl get svc -n aim-engine

# Expected output:
NAME                  TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
aim-engine-service    NodePort   10.96.123.45    <none>        8000:30080/TCP   2m

# Get service URL
minikube service aim-engine -n aim-engine --url

# Expected output:
http://192.168.49.2:30080
```

### **Check Monitoring**
```bash
# Check monitoring resources
kubectl get servicemonitor -n aim-engine-monitoring

# Expected output:
NAME                    AGE
aim-engine-monitoring   2m

# Check Prometheus rules
kubectl get prometheusrule -n aim-engine-monitoring

# Expected output:
NAME                    AGE
aim-engine-alerts       2m
```

## **Troubleshooting**

### **Common Issues**

#### **Minikube Not Starting**
```bash
# Check Minikube status
minikube status

# If not running, start with more resources
minikube start --driver=docker --cpus=6 --memory=12288 --disk-size=30g

# If still failing, try with different driver
minikube start --driver=virtualbox --cpus=4 --memory=8192
```

#### **Pod Not Starting**
```bash
# Check pod status
kubectl get pods -n aim-engine

# Check pod events
kubectl describe pod -n aim-engine -l app=aim-engine

# Check pod logs
kubectl logs -n aim-engine deployment/aim-engine

# Common issues:
# - Insufficient resources: Increase Minikube resources
# - Image pull errors: Check Docker image availability
# - Volume mount issues: Check storage configuration
```

#### **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n aim-engine

# Check service configuration
kubectl describe svc -n aim-engine aim-engine-service

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://aim-engine-service:8000/health

# Port forward for testing
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
```

#### **Recipe Selection Failing**
```bash
# Check recipe selector job
kubectl get jobs -n aim-engine

# Check job logs
kubectl logs -n aim-engine job/aim-engine-recipe-selector

# Check recipe ConfigMap
kubectl get configmap -n aim-engine aim-engine-recipe-config -o yaml

# Common issues:
# - Recipe not found: Check available recipes
# - Resource constraints: Increase Minikube resources
# - Configuration errors: Check recipe format
```

#### **Monitoring Not Working**
```bash
# Check monitoring pods
kubectl get pods -n aim-engine-monitoring

# Check ServiceMonitor
kubectl get servicemonitor -n aim-engine-monitoring

# Check Prometheus rules
kubectl get prometheusrule -n aim-engine-monitoring

# Test metrics endpoint
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
curl http://localhost:8000/metrics
```

### **Debug Commands**

#### **Resource Usage**
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n aim-engine

# Check resource requests/limits
kubectl describe pod -n aim-engine -l app=aim-engine | grep -A 10 "Containers:"
```

#### **Network Issues**
```bash
# Check DNS resolution
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup aim-engine-service

# Check network policies
kubectl get networkpolicy -n aim-engine

# Test connectivity
kubectl run test-connectivity --image=busybox --rm -it --restart=Never -- wget -O- http://aim-engine-service:8000/health
```

#### **Storage Issues**
```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc -n aim-engine

# Check storage class
kubectl get storageclass
```

### **Reset and Restart**

#### **Complete Reset**
```bash
# Delete all resources
kubectl delete namespace aim-engine --ignore-not-found=true
kubectl delete namespace aim-engine-monitoring --ignore-not-found=true

# Restart Minikube
minikube stop
minikube start --driver=docker --cpus=6 --memory=16384 --disk-size=30g

# Redeploy
cd k8s/minikube
./deploy.sh
```

#### **Partial Reset**
```bash
# Delete only deployment
kubectl delete deployment aim-engine -n aim-engine

# Redeploy
cd k8s/minikube
./deploy.sh
```

## **Development Workflow**

### **Typical Development Cycle**
1. **Start Minikube**: `minikube start --driver=docker --cpus=4 --memory=8192`
2. **Deploy AIM Engine**: `cd k8s/minikube && ./deploy.sh`
3. **Test functionality**: `./test-recipe.sh`
4. **Make changes**: Modify code or configuration
5. **Redeploy**: `./deploy.sh`
6. **Test again**: `./test-recipe.sh`
7. **Iterate**: Repeat steps 4-6

### **Testing Different Configurations**
```bash
# Test with mock server
./deploy.sh

# Test with TGI server
./deploy.sh tgi

# Test with different models
# Edit k8s/minikube/recipe-selector-job.yaml
# Change MODEL_ID to different model
./deploy.sh
```

## **Next Steps**

### **Local Development**
- **Code changes**: Modify AIM Engine source code
- **Configuration changes**: Update recipe configurations
- **Testing**: Use included test scripts
- **Validation**: Verify functionality before production

### **Production Preparation**
- **Performance testing**: Test with larger models
- **Resource optimization**: Tune resource requirements
- **Monitoring setup**: Configure production monitoring
- **Security review**: Review security configurations

### **Integration Testing**
- **API testing**: Test all endpoints thoroughly
- **Load testing**: Test with multiple concurrent requests
- **Error handling**: Test error scenarios
- **Recovery testing**: Test failure and recovery scenarios

This comprehensive development guide provides everything you need to test AIM Engine functionality in Minikube! 