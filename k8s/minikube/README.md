# AIM Engine Minikube Deployment with Recipe Support

## 🎯 **Overview**

This enhanced Minikube deployment includes **recipe selection** and **monitoring capabilities**, making it a feature-complete development environment for testing AIM Engine functionality.

## 🚀 **Features**

### **✅ Recipe Selection**
- **Automatic recipe selection** based on model and resources
- **Mock recipe configuration** for development testing
- **Recipe validation** and fallback mechanisms
- **Configuration overrides** support

### **✅ Monitoring & Observability**
- **Prometheus metrics** endpoint (`/metrics`)
- **Health checks** endpoint (`/health`)
- **Recipe information** endpoint (`/recipe`)
- **ServiceMonitor** for Prometheus integration
- **Basic Grafana dashboard** configuration

### **✅ Development Features**
- **Mock vLLM server** with recipe-aware responses
- **TGI server** for real inference capabilities
- **Comprehensive logging** and debugging
- **Resource optimization** for Minikube constraints
- **Easy testing** with included test scripts

## 📋 **Prerequisites**

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

## 🚀 **Quick Start**

### **1. Start Minikube**
```bash
# Start Minikube with sufficient resources
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable storage-provisioner
```

### **2. Deploy AIM Engine**

#### **Option A: Mock Server (Default)**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with mock server
./deploy.sh
```

#### **Option B: TGI Server (Real Inference)**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with TGI for real inference
./deploy.sh tgi
```

### **3. Test the Deployment**
```bash
# Test mock server functionality
./test-recipe.sh

# Test TGI inference (if deployed with TGI)
./test-tgi.sh
```

## 🔧 **Configuration**

### **Recipe Configuration**

The deployment automatically selects a recipe based on available resources:

#### **Mock Server (Default)**
```yaml
# Default recipe for Minikube mock server
recipe_id: qwen3-32b-1gpu-bf16
model_id: Qwen/Qwen3-32B
gpu_count: 1
precision: bf16
backend: vllm
```

#### **TGI Server**
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
  value: "Qwen/Qwen3-7B"  # Change model
- name: GPU_COUNT
  value: "1"              # Change GPU count
- name: PRECISION
  value: "bf16"           # Change precision
```

## 📊 **Monitoring**

### **Available Endpoints**

#### **Mock Server Endpoints**
| Endpoint | Description | Example |
|----------|-------------|---------|
| `/` | Main web interface | Shows recipe configuration |
| `/metrics` | Prometheus metrics | Recipe and performance metrics |
| `/health` | Health check | JSON health status |
| `/recipe` | Recipe information | Detailed recipe configuration |

#### **TGI Server Endpoints**
| Endpoint | Description | Example |
|----------|-------------|---------|
| `/health` | Health check | JSON health status |
| `/info` | Model information | Model details and configuration |
| `/generate` | Text generation | POST with input text and parameters |
| `/metrics` | Prometheus metrics | Performance and usage metrics |

### **Accessing Endpoints**

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

### **Prometheus Integration**

If you have Prometheus Operator installed:

```bash
# Check if monitoring is enabled
kubectl get servicemonitor -n aim-engine-monitoring

# View monitoring resources
kubectl get all -n aim-engine-monitoring
```

## 🧪 **Testing**

### **Automated Testing**
```bash
# Run comprehensive tests
./test-recipe.sh
```

### **Manual Testing**
```bash
# Check deployment status
kubectl get all -n aim-engine

# Check recipe configuration
kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml

# View logs
kubectl logs -n aim-engine deployment/aim-engine --tail=50

# Test endpoints
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
curl http://localhost:8000/recipe | jq '.'
```

## 📈 **Metrics**

### **Available Metrics**

The deployment exposes the following Prometheus metrics:

- `aim_recipe_selection_total` - Total recipe selections
- `aim_performance_tokens_per_second` - Performance throughput
- `aim_gpu_memory_utilization` - GPU memory utilization
- `aim_engine_requests_total` - Request count

### **Sample Metrics Output**
```
# HELP aim_recipe_selection_total Total number of recipe selections
# TYPE aim_recipe_selection_total counter
aim_recipe_selection_total{recipe_id="qwen3-32b-1gpu-bf16",model="Qwen/Qwen3-32B",gpu_count="1",precision="bf16"} 1

# HELP aim_performance_tokens_per_second Tokens per second (mock)
# TYPE aim_performance_tokens_per_second gauge
aim_performance_tokens_per_second{recipe_id="qwen3-32b-1gpu-bf16"} 150.5
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Recipe Selection Fails**
```bash
# Check recipe selector job
kubectl get jobs -n aim-engine
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook

# Check recipe ConfigMap
kubectl get configmap aim-engine-recipe-config -n aim-engine
```

#### **Service Not Accessible**
```bash
# Check service status
kubectl get svc -n aim-engine

# Check pod status
kubectl get pods -n aim-engine

# Check pod logs
kubectl logs -n aim-engine deployment/aim-engine
```

#### **Monitoring Not Working**
```bash
# Check if Prometheus Operator is installed
kubectl get crd servicemonitors.monitoring.coreos.com

# Check monitoring resources
kubectl get all -n aim-engine-monitoring
```

### **Debug Commands**
```bash
# Get detailed pod information
kubectl describe pod -n aim-engine -l app=aim-engine

# Check events
kubectl get events -n aim-engine --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n aim-engine
```

## 🧹 **Cleanup**

### **Remove Deployment**
```bash
# Remove all resources
kubectl delete namespace aim-engine --ignore-not-found=true
kubectl delete namespace aim-engine-monitoring --ignore-not-found=true

# Stop Minikube
minikube stop
```

### **Reset Minikube**
```bash
# Complete reset
minikube delete
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g
```

## 🎯 **Next Steps**

### **Development Workflow**
1. **Deploy** with `./deploy.sh`
2. **Test** with `./test-recipe.sh`
3. **Develop** and iterate
4. **Monitor** performance and metrics
5. **Clean up** when done

### **Production Migration**
When ready for production:
1. **Stop Minikube**: `minikube stop`
2. **Set up production cluster** with AMD GPUs
3. **Deploy using production scripts**: `../scripts/deploy-with-recipe-support.sh`
4. **Configure real monitoring** with Prometheus/Grafana

## 📚 **Additional Resources**

- [Main Deployment Workflow](../docs/DEPLOYMENT_WORKFLOW.md)
- [Quick Reference](../docs/QUICK_REFERENCE.md)
- [Production Deployment](../production/)
- [Helm Charts](../helm/)

This enhanced Minikube deployment provides a **complete development environment** for testing AIM Engine with full recipe support and monitoring capabilities! 🚀 