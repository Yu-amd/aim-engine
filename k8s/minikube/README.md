# AIM Engine Minikube Development Guide

## **Overview**

This guide provides everything you need to deploy and test AIM Engine in Minikube for development, testing, and learning purposes. Minikube provides a lightweight Kubernetes environment perfect for development without requiring GPU hardware.

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

### **System Requirements**
- **Docker**: Installed and running
- **Minikube**: Latest version installed
- **kubectl**: Configured for Minikube
- **Memory**: At least 4GB available RAM
- **Storage**: At least 10GB free disk space

### **Software Installation**
```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
minikube version
kubectl version --client
```

### **Docker Driver Support**
```bash
# Check Docker
docker --version

# Ensure Docker is running
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (if needed)
sudo usermod -aG docker $USER
newgrp docker
```

## **Quick Start**

### **1. Start Minikube**
```bash
# Start Minikube with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

### **2. Build and Load Docker Image**
```bash
# Build AIM Engine image
./scripts/build-aim-vllm.sh

# Load image into Minikube
minikube image load aim-vllm:latest

# Verify image is loaded
minikube image ls | grep aim-vllm
```

### **3. Deploy AIM Engine**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with mock server (default)
./deploy.sh

# Or deploy with TGI server
./deploy.sh tgi
```

### **4. Verify Deployment**
```bash
# Check deployment status
kubectl get pods -n aim-engine

# Check services
kubectl get services -n aim-engine

# Check recipe configuration
kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml
```

### **5. Access the Service**
```bash
# Port forward to service
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/recipe
curl http://localhost:8000/metrics
```

## **Configuration**

### **Environment Variables**
```bash
# Model configuration
MODEL_ID=microsoft/DialoGPT-medium
PRECISION=float16
BACKEND=tgi

# Resource configuration
GPU_COUNT=1
MEMORY_LIMIT=4Gi
CPU_LIMIT=2

# Performance configuration
MAX_BATCH_SIZE=8
MAX_INPUT_LENGTH=1024
MAX_OUTPUT_LENGTH=512
```

### **Recipe Configuration**
```yaml
# Example recipe for Minikube
recipe_id: dialogpt-medium-1gpu-float16
huggingface_id: microsoft/DialoGPT-medium
hardware: CPU
gpu_count: 1
precision: float16
backend: tgi
config:
  args:
    model_id: microsoft/DialoGPT-medium
    dtype: float16
    port: 8000
    hostname: 0.0.0.0
    max_batch_total_tokens: 4096
    max_batch_prefill_tokens: 2048
    max_input_length: 1024
    max_total_tokens: 2048
performance:
  expected_tokens_per_second: 50
  expected_latency_ms: 500
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "8Gi"
    cpu: "4"
```

### **Custom Configuration**
```bash
# Deploy with custom model
./deploy.sh tgi --model microsoft/DialoGPT-small

# Deploy with custom resources
./deploy.sh --memory 8Gi --cpu 4

# Deploy with custom recipe
./deploy.sh --recipe custom-recipe.yaml
```

## **Monitoring**

### **Prometheus Integration**
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n aim-engine

# Check Prometheus targets
kubectl port-forward service/prometheus 9090:9090 -n monitoring
# Access: http://localhost:9090

# Query metrics
curl -G http://localhost:9090/api/v1/query --data-urlencode 'query=aim_recipe_selection_total'
```

### **Grafana Dashboard**
```bash
# Port forward to Grafana
kubectl port-forward service/grafana 3000:3000 -n monitoring

# Access dashboard
# URL: http://localhost:3000
# Username: admin
# Password: admin
```

### **Custom Metrics**
```bash
# View available metrics
curl http://localhost:8000/metrics | grep aim_

# Example metrics
# aim_recipe_selection_total{result="success"} 1
# aim_performance_tokens_per_second 45.2
# aim_gpu_memory_utilization 0.75
```

### **Logging**
```bash
# View pod logs
kubectl logs -f deployment/aim-engine -n aim-engine

# View recipe selector logs
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# View events
kubectl get events -n aim-engine --sort-by='.lastTimestamp'
```

## **Testing**

### **Automated Testing**
```bash
# Run mock server tests
./test-recipe.sh

# Run TGI server tests
./test-tgi.sh

# Run performance tests
./test-performance.sh
```

### **Manual Testing**
```bash
# Test health endpoint
curl http://localhost:8000/health

# Test recipe endpoint
curl http://localhost:8000/recipe

# Test metrics endpoint
curl http://localhost:8000/metrics

# Test TGI endpoints (if using TGI)
curl http://localhost:8000/info
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"inputs": "Hello", "parameters": {"max_new_tokens": 50}}'
```

### **Performance Testing**
```bash
# Load testing
for i in {1..10}; do
  curl -X POST http://localhost:8000/generate \
    -H "Content-Type: application/json" \
    -d '{"inputs": "Test request '$i'", "parameters": {"max_new_tokens": 20}}' &
done
wait

# Monitor resource usage
kubectl top pods -n aim-engine
kubectl exec deployment/aim-engine -n aim-engine -- free -h
```

## **Troubleshooting**

### **Common Issues**

#### **Pod Not Starting**
```bash
# Check pod status
kubectl describe pod -n aim-engine deployment/aim-engine

# Check resource limits
kubectl describe node minikube

# Check image availability
minikube image ls | grep aim-vllm
```

#### **Service Not Accessible**
```bash
# Check service configuration
kubectl get service aim-engine-service -n aim-engine -o yaml

# Check endpoints
kubectl get endpoints -n aim-engine

# Test port forwarding
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
```

#### **Recipe Selection Issues**
```bash
# Check recipe selector job
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# Check recipe configmap
kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml

# Verify recipe files
kubectl get configmap -n aim-engine | grep recipe
```

#### **Memory Issues**
```bash
# Check available memory
kubectl describe node minikube | grep -A 5 "Allocated resources"

# Increase Minikube memory
minikube stop
minikube start --driver=docker --cpus=6 --memory=12288 --disk-size=30g
```

### **Debug Commands**
```bash
# Enable debug logging
kubectl patch deployment aim-engine -n aim-engine -p '{"spec":{"template":{"spec":{"containers":[{"name":"aim-engine","env":[{"name":"LOG_LEVEL","value":"DEBUG"}]}]}}}}'

# Check pod events
kubectl get events -n aim-engine --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n aim-engine
kubectl top nodes
```

### **Reset Environment**
```bash
# Clean up deployment
kubectl delete namespace aim-engine

# Reset Minikube
minikube stop
minikube delete
minikube start --driver=docker --cpus=6 --memory=16384 --disk-size=30g

# Rebuild and redeploy
./scripts/build-aim-vllm.sh
minikube image load aim-vllm:latest
./deploy.sh
```

## **Next Steps**

### **Development Workflow**
1. **Start Minikube**: `minikube start --driver=docker --cpus=4 --memory=8192`
2. **Deploy AIM Engine**: `./deploy.sh`
3. **Test Changes**: Use test scripts and manual testing
4. **Monitor Performance**: Use Grafana dashboard
5. **Iterate**: Make changes and redeploy

### **Production Preparation**
1. **Test with Real Models**: Use TGI server with actual models
2. **Validate Performance**: Ensure performance meets requirements
3. **Test Scaling**: Verify horizontal pod autoscaling
4. **Security Review**: Check RBAC and network policies
5. **Documentation**: Update deployment guides

### **Advanced Features**
1. **Custom Recipes**: Create recipes for your specific models
2. **Monitoring Alerts**: Set up Prometheus alerting rules
3. **CI/CD Integration**: Automate deployment testing
4. **Multi-Model Testing**: Test multiple models simultaneously
5. **Performance Optimization**: Tune recipes for better performance

## **Additional Resources**

- **[Production Guide](../docs/PRODUCTION.md)**: Full Kubernetes deployment
- **[AMD GPU Setup](../docs/amd-gpu-setup.md)**: GPU configuration guide
- **[Recipe System](../../docs/RECIPE_GUIDE.md)**: Recipe development guide
- **[Troubleshooting](../../docs/TROUBLESHOOTING.md)**: Common issues and solutions

Your AIM Engine is now running in Minikube with full recipe support and monitoring capabilities! 