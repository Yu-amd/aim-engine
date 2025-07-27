# TGI (Text Generation Inference) Usage Guide

## **Overview**

This guide covers the usage of Text Generation Inference (TGI) server in the AIM Engine Minikube environment. TGI provides real inference capabilities for development and testing without requiring GPU hardware.

## **Quick Start**

### **Deploy with TGI Server**
```bash
# Navigate to Minikube directory
cd k8s/minikube

# Deploy with TGI server
./deploy.sh tgi

# Verify deployment
kubectl get pods -n aim-engine
kubectl logs deployment/aim-engine -n aim-engine
```

### **Access TGI Endpoints**
```bash
# Port forward to service
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Test health endpoint
curl http://localhost:8000/health

# Test model info
curl http://localhost:8000/info
```

### **Basic Text Generation**
```bash
# Generate text with TGI
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Hello, how are you?",
    "parameters": {
      "max_new_tokens": 50,
      "temperature": 0.7,
      "top_p": 0.9
    }
  }'
```

## **TGI API Endpoints**

### **Health Check**
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "model": "microsoft/DialoGPT-medium",
  "backend": "tgi"
}
```

### **Model Information**
```bash
GET /info
```

**Response:**
```json
{
  "model_id": "microsoft/DialoGPT-medium",
  "model_type": "gpt2",
  "backend": "text-generation-inference",
  "dtype": "float16",
  "device": "cpu",
  "max_input_length": 1024,
  "max_total_tokens": 2048,
  "max_batch_total_tokens": 4096,
  "max_batch_prefill_tokens": 2048
}
```

### **Text Generation**
```bash
POST /generate
```

**Request Body:**
```json
{
  "inputs": "Your input text here",
  "parameters": {
    "max_new_tokens": 100,
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 50,
    "repetition_penalty": 1.1,
    "do_sample": true,
    "stop": ["\n", "END"]
  }
}
```

**Response:**
```json
{
  "generated_text": "Generated response text",
  "finish_reason": "length",
  "generated_tokens": 50,
  "prefill_tokens": 10,
  "seed": 42
}
```

### **Streaming Generation**
```bash
POST /generate_stream
```

**Request Body:**
```json
{
  "inputs": "Your input text here",
  "parameters": {
    "max_new_tokens": 100,
    "temperature": 0.7,
    "stream": true
  }
}
```

**Response (Stream):**
```
data: {"token": {"id": 1, "text": "Hello", "logprob": -0.1}}
data: {"token": {"id": 2, "text": " world", "logprob": -0.2}}
data: {"token": {"id": 3, "text": "!", "logprob": -0.3}}
data: [DONE]
```

### **Metrics Endpoint**
```bash
GET /metrics
```

**Response:**
```
# HELP tgi_requests_total Total number of requests
# TYPE tgi_requests_total counter
tgi_requests_total 150

# HELP tgi_tokens_generated_total Total tokens generated
# TYPE tgi_tokens_generated_total counter
tgi_tokens_generated_total 5000

# HELP tgi_request_duration_seconds Request duration
# TYPE tgi_request_duration_seconds histogram
tgi_request_duration_seconds_bucket{le="0.1"} 50
tgi_request_duration_seconds_bucket{le="0.5"} 100
tgi_request_duration_seconds_bucket{le="1.0"} 150
```

## **Configuration Options**

### **Model Configuration**
```yaml
# TGI model configuration
model:
  id: "microsoft/DialoGPT-medium"
  type: "gpt2"
  dtype: "float16"
  max_input_length: 1024
  max_total_tokens: 2048
  max_batch_total_tokens: 4096
  max_batch_prefill_tokens: 2048
```

### **Server Configuration**
```yaml
# TGI server configuration
server:
  host: "0.0.0.0"
  port: 8000
  max_concurrent_requests: 10
  max_waiting_tokens: 20
  max_batch_size: 8
  max_batch_prefill_tokens: 2048
  max_batch_total_tokens: 4096
```

### **Generation Parameters**
```yaml
# Default generation parameters
generation:
  max_new_tokens: 100
  temperature: 0.7
  top_p: 0.9
  top_k: 50
  repetition_penalty: 1.1
  do_sample: true
  stop_sequences: ["\n", "END"]
```

### **Performance Configuration**
```yaml
# Performance tuning
performance:
  num_workers: 1
  max_concurrent_requests: 10
  max_waiting_tokens: 20
  max_batch_size: 8
  max_batch_prefill_tokens: 2048
  max_batch_total_tokens: 4096
```

## **Performance Monitoring**

### **Key Metrics**

#### **Throughput Metrics**
- **Requests per Second**: Number of requests processed per second
- **Tokens per Second**: Number of tokens generated per second
- **Batch Processing**: Average batch size and processing time

#### **Latency Metrics**
- **Request Duration**: Time to process each request
- **Token Generation Time**: Time per generated token
- **Queue Wait Time**: Time requests wait in queue

#### **Resource Metrics**
- **CPU Utilization**: CPU usage percentage
- **Memory Usage**: Memory consumption
- **Model Loading Time**: Time to load model into memory

### **Monitoring Setup**
```bash
# Check TGI metrics
curl http://localhost:8000/metrics | grep tgi_

# Monitor resource usage
kubectl top pods -n aim-engine

# Check logs for performance issues
kubectl logs deployment/aim-engine -n aim-engine | grep -i performance
```

### **Performance Optimization**
```bash
# Optimize batch size
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "Test input",
    "parameters": {
      "max_new_tokens": 50,
      "temperature": 0.1
    }
  }'

# Test with different models
./deploy.sh tgi --model microsoft/DialoGPT-small
./deploy.sh tgi --model microsoft/DialoGPT-large
```

## **Troubleshooting**

### **Common Issues**

#### **Model Loading Failures**
```bash
# Check model download
kubectl logs deployment/aim-engine -n aim-engine | grep -i "model"

# Verify model cache
kubectl exec deployment/aim-engine -n aim-engine -- ls -la /workspace/model-cache

# Check disk space
kubectl exec deployment/aim-engine -n aim-engine -- df -h
```

#### **Memory Issues**
```bash
# Check memory usage
kubectl top pods -n aim-engine

# Monitor memory in container
kubectl exec deployment/aim-engine -n aim-engine -- free -h

# Check for OOM errors
kubectl describe pod -n aim-engine deployment/aim-engine | grep -i "oom"
```

#### **Performance Issues**
```bash
# Check CPU usage
kubectl top pods -n aim-engine

# Monitor request queue
curl http://localhost:8000/metrics | grep queue

# Check for bottlenecks
kubectl logs deployment/aim-engine -n aim-engine | grep -i "slow"
```

### **Debug Commands**
```bash
# Enable debug logging
kubectl patch deployment aim-engine -n aim-engine -p '{"spec":{"template":{"spec":{"containers":[{"name":"aim-engine","env":[{"name":"LOG_LEVEL","value":"DEBUG"}]}]}}}}'

# Check TGI server status
kubectl exec deployment/aim-engine -n aim-engine -- ps aux | grep tgi

# Test model loading
kubectl exec deployment/aim-engine -n aim-engine -- python3 -c "from transformers import AutoModel; print('Model loading test')"
```

### **Reset and Recovery**
```bash
# Restart TGI server
kubectl rollout restart deployment/aim-engine -n aim-engine

# Clear model cache
kubectl exec deployment/aim-engine -n aim-engine -- rm -rf /workspace/model-cache/*

# Redeploy with fresh configuration
kubectl delete namespace aim-engine
./deploy.sh tgi
```

## **Advanced Usage**

### **Custom Model Deployment**
```bash
# Deploy with custom model
./deploy.sh tgi --model microsoft/DialoGPT-small

# Deploy with custom parameters
./deploy.sh tgi --max-tokens 200 --temperature 0.5

# Deploy with custom configuration
cat > custom-tgi-config.yaml << EOF
model:
  id: "microsoft/DialoGPT-small"
  dtype: "float16"
  max_input_length: 512
server:
  max_concurrent_requests: 5
  max_batch_size: 4
EOF

./deploy.sh tgi --config custom-tgi-config.yaml
```

### **Load Testing**
```bash
# Simple load test
for i in {1..10}; do
  curl -X POST http://localhost:8000/generate \
    -H "Content-Type: application/json" \
    -d '{
      "inputs": "Test request '$i'",
      "parameters": {
        "max_new_tokens": 20,
        "temperature": 0.1
      }
    }' &
done
wait

# Monitor performance during load test
kubectl top pods -n aim-engine
curl http://localhost:8000/metrics | grep tgi_requests_total
```

### **Integration Testing**
```bash
# Test health endpoint
curl -f http://localhost:8000/health || echo "Health check failed"

# Test model info
curl -f http://localhost:8000/info || echo "Model info failed"

# Test text generation
curl -f -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"inputs": "Test", "parameters": {"max_new_tokens": 10}}' || echo "Generation failed"
```

### **Performance Benchmarking**
```bash
# Benchmark different models
models=("microsoft/DialoGPT-small" "microsoft/DialoGPT-medium" "microsoft/DialoGPT-large")

for model in "${models[@]}"; do
  echo "Testing $model"
  ./deploy.sh tgi --model "$model"
  sleep 30
  
  # Run benchmark
  start_time=$(date +%s)
  for i in {1..10}; do
    curl -s -X POST http://localhost:8000/generate \
      -H "Content-Type: application/json" \
      -d '{"inputs": "Benchmark test", "parameters": {"max_new_tokens": 50}}' > /dev/null
  done
  end_time=$(date +%s)
  
  echo "$model: $((end_time - start_time)) seconds for 10 requests"
done
```

### **Custom TGI Configuration**
```python
# Custom TGI server configuration
import text_generation

# Configure TGI server
server_config = {
    "model_id": "microsoft/DialoGPT-medium",
    "dtype": "float16",
    "max_input_length": 1024,
    "max_total_tokens": 2048,
    "max_batch_total_tokens": 4096,
    "max_batch_prefill_tokens": 2048,
    "max_concurrent_requests": 10,
    "max_waiting_tokens": 20,
    "max_batch_size": 8
}

# Start TGI server
server = text_generation.Server(server_config)
server.start()
```

## **Next Steps**

### **Development Workflow**
1. **Start TGI Server**: Deploy with `./deploy.sh tgi`
2. **Test Endpoints**: Verify all endpoints are working
3. **Load Testing**: Test performance under load
4. **Integration**: Integrate with your applications
5. **Monitoring**: Set up monitoring and alerting
6. **Optimization**: Optimize based on performance data

### **Production Preparation**
1. **Performance Testing**: Test with production workloads
2. **Load Testing**: Verify performance under expected load
3. **Monitoring Setup**: Configure comprehensive monitoring
4. **Security Review**: Review security configurations
5. **Documentation**: Update deployment documentation
6. **Training**: Train team on TGI usage

### **Advanced Features**
1. **Custom Models**: Deploy your own fine-tuned models
2. **Model Optimization**: Optimize models for better performance
3. **Scaling**: Scale TGI servers horizontally
4. **Caching**: Implement response caching
5. **Load Balancing**: Set up load balancing across multiple TGI instances

Your TGI server is now running and ready for development and testing with real inference capabilities! 