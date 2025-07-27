# TGI Usage Guide for Minikube

## 🎯 **Overview**

This guide explains how to use Text Generation Inference (TGI) with AIM Engine in Minikube for real inference capabilities during development.

## 🚀 **Quick Start**

### **1. Deploy with TGI**
```bash
cd k8s/minikube
./deploy.sh tgi
```

### **2. Test TGI Functionality**
```bash
./test-tgi.sh
```

### **3. Access TGI API**
```bash
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
```

## 📋 **TGI API Endpoints**

### **Health Check**
```bash
curl http://localhost:8000/health
```

**Response:**
```json
{
  "status": "healthy",
  "model_id": "microsoft/DialoGPT-medium",
  "backend": "tgi"
}
```

### **Model Information**
```bash
curl http://localhost:8000/info
```

**Response:**
```json
{
  "model_id": "microsoft/DialoGPT-medium",
  "model_type": "gpt2",
  "backend": "text-generation-inference",
  "version": "1.4.0"
}
```

### **Text Generation**
```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Hello, how are you?",
    "parameters": {
      "max_new_tokens": 50,
      "temperature": 0.7,
      "top_p": 0.9,
      "do_sample": true
    }
  }'
```

**Response:**
```json
{
  "generated_text": "Hello, how are you? I'm doing well, thank you for asking! How about you?",
  "details": {
    "finish_reason": "length",
    "generated_tokens": 15,
    "seed": 42
  }
}
```

## 🔧 **Configuration Options**

### **Generation Parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_new_tokens` | int | 20 | Maximum number of tokens to generate |
| `temperature` | float | 1.0 | Controls randomness (0.0 = deterministic) |
| `top_p` | float | 1.0 | Nucleus sampling parameter |
| `top_k` | int | 50 | Top-k sampling parameter |
| `do_sample` | bool | true | Whether to use sampling |
| `repetition_penalty` | float | 1.0 | Penalty for repeating tokens |

### **Example Configurations**

#### **Creative Writing**
```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Once upon a time",
    "parameters": {
      "max_new_tokens": 100,
      "temperature": 0.9,
      "top_p": 0.8,
      "do_sample": true
    }
  }'
```

#### **Code Generation**
```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "def fibonacci",
    "parameters": {
      "max_new_tokens": 50,
      "temperature": 0.3,
      "top_p": 0.9,
      "do_sample": true
    }
  }'
```

#### **Question Answering**
```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "What is the capital of France?",
    "parameters": {
      "max_new_tokens": 30,
      "temperature": 0.1,
      "top_p": 0.9,
      "do_sample": false
    }
  }'
```

## 📊 **Performance Monitoring**

### **Check Resource Usage**
```bash
# Check pod resource usage
kubectl top pods -n aim-engine

# Check pod logs
kubectl logs -f deployment/aim-engine -n aim-engine

# Check pod events
kubectl get events -n aim-engine --sort-by='.lastTimestamp'
```

### **Performance Metrics**
```bash
# Get metrics
curl http://localhost:8000/metrics

# Sample metrics output:
# text_generation_requests_total{method="generate"} 42
# text_generation_request_duration_seconds{method="generate"} 0.5
# text_generation_tokens_generated_total 1500
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Model Loading Takes Too Long**
```bash
# Check model download progress
kubectl logs -f deployment/aim-engine -n aim-engine | grep -E "(download|load)"

# Increase Minikube resources
minikube stop
minikube start --driver=docker --cpus=6 --memory=12288 --disk-size=30g
```

#### **Out of Memory Errors**
```bash
# Check memory usage
kubectl top pods -n aim-engine

# Reduce model size or increase Minikube memory
minikube start --driver=docker --cpus=4 --memory=16384 --disk-size=20g
```

#### **TGI Server Not Starting**
```bash
# Check TGI server logs
kubectl logs deployment/aim-engine -n aim-engine | grep -i tgi

# Check if model is available
curl http://localhost:8000/info
```

### **Debug Commands**
```bash
# Get detailed pod information
kubectl describe pod -n aim-engine -l app=aim-engine

# Check container status
kubectl get pods -n aim-engine -o wide

# Access container shell
kubectl exec -it deployment/aim-engine -n aim-engine -- bash
```

## 🎯 **Advanced Usage**

### **Batch Processing**
```bash
# Process multiple requests
for prompt in "Hello" "How are you?" "What's the weather?"; do
  curl -X POST http://localhost:8000/generate \
    -H "Content-Type: application/json" \
    -d "{\"inputs\": \"$prompt\", \"parameters\": {\"max_new_tokens\": 30}}" &
done
wait
```

### **Streaming Responses**
```bash
# Note: Basic TGI doesn't support streaming, but you can simulate it
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Tell me a story",
    "parameters": {
      "max_new_tokens": 100,
      "temperature": 0.8
    }
  }' | jq -r '.generated_text'
```

### **Custom Model Configuration**
```bash
# Edit recipe configuration
kubectl edit configmap aim-engine-recipe-config -n aim-engine

# Change model or parameters
# Then restart the deployment
kubectl rollout restart deployment/aim-engine -n aim-engine
```

## 📈 **Performance Optimization**

### **Resource Allocation**
```bash
# Check current resource allocation
kubectl get deployment aim-engine -n aim-engine -o yaml | grep -A 10 resources

# Adjust resources if needed
kubectl patch deployment aim-engine -n aim-engine -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "aim-engine",
          "resources": {
            "requests": {"memory": "6Gi", "cpu": "3"},
            "limits": {"memory": "10Gi", "cpu": "4"}
          }
        }]
      }
    }
  }
}'
```

### **Model Optimization**
- Use smaller models for faster loading
- Adjust batch sizes based on available memory
- Use appropriate precision (float16 vs float32)

## 🧹 **Cleanup**

### **Remove TGI Deployment**
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

## 🎉 **Next Steps**

1. **Test different models** by changing the model_id in recipe configuration
2. **Experiment with parameters** to find optimal settings for your use case
3. **Scale up** to production deployment when ready
4. **Monitor performance** and optimize resource usage

TGI provides **real inference capabilities** in your Minikube development environment, making it much easier to test and validate AIM Engine functionality! 🚀 