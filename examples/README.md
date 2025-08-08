# AIM Engine Examples

This directory contains various examples for using AIM Engine:

## **Docker Examples** (Single Node)
Traditional Docker-based examples for local development and testing.

## **Kubernetes Examples** (Multi-Node)
Modern Kubernetes-based examples using the AIM Engine operator for production deployments.

---

## **Quick Navigation**

- **🐳 [Docker Examples](docker/README.md)** - Single-node development and testing
- **☸️ [Kubernetes Examples](kubernetes/README.md)** - Multi-node production deployments

---

## **Docker Examples**

These examples use the traditional Docker deployment approach for single-node setups.

### **Available Docker Examples**

1. **Simple Agent** (`docker/simple_agent.py`)
   - Basic conversational agent with streaming responses
   - Conversation history and system prompts

2. **Advanced Agent** (`docker/advanced_agent.py`)
   - Tool integration (calculator, file reader, time)
   - Memory system with relevance matching
   - Structured tool calling

3. **Web Agent** (`docker/web_agent.py`)
   - Web interface for browser interaction
   - RESTful API endpoints
   - Real-time streaming responses

4. **Test Streaming** (`docker/test_streaming.py`)
   - Streaming response testing
   - Performance measurement

5. **Quick Start Script** (`docker/quick_start.sh`)
   - Automated setup and testing

### **Quick Start with Docker**

```bash
# Start AIM Engine
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell

# Run an example
python3 docker/simple_agent.py
```

For detailed Docker examples documentation, see [docker/README.md](docker/README.md).

---

## **🚀 Kubernetes Examples**

For production deployments and multi-node setups, check out our Kubernetes examples:

### **Available Kubernetes Examples**

1. **Basic AIM Deployment** (`kubernetes/basic-aim/`)
   - Simple single AIM deployment
   - Basic resource configuration
   - Health monitoring and client interaction

2. **Multi-Model AIMs** (`kubernetes/multi-model/`)
   - Multiple AIM instances with different models
   - Load balancing and model comparison
   - Concurrent testing capabilities

3. **AIM with Caching** (`kubernetes/cached-aim/`)
   - Persistent volume caching
   - Model caching across restarts
   - Performance comparison

4. **Scalable AIM** (`kubernetes/scalable-aim/`)
   - Horizontal Pod Autoscaler
   - Load-based scaling
   - Load testing and performance monitoring

5. **AIM with Monitoring** (`kubernetes/monitored-aim/`)
   - Prometheus metrics
   - Grafana dashboards
   - Health checks and alerts

6. **Production AIM** (`kubernetes/production-aim/`)
   - High availability setup
   - Security policies
   - Backup and recovery

### **Quick Start with Kubernetes**

```bash
# Deploy AIM Engine operator
cd k8s/operator
./scripts/setup-and-test-operator.sh

# Deploy a basic AIM
cd examples/kubernetes/basic-aim
./deploy.sh

# Set up port forwarding
kubectl port-forward svc/basic-aim 8000:8000 -n aim-engine

# Run the client
python3 client.py
```

### **Kubernetes vs Docker Examples**

| Feature | Docker Examples | Kubernetes Examples |
|---------|----------------|-------------------|
| **Deployment** | Single node | Multi-node cluster |
| **Scaling** | Manual | Automatic (HPA) |
| **High Availability** | No | Yes |
| **Resource Management** | Basic | Advanced |
| **Monitoring** | Limited | Comprehensive |
| **Use Case** | Development/Testing | Production |

For detailed Kubernetes examples documentation, see [kubernetes/README.md](kubernetes/README.md).

---

## **🎯 Choosing the Right Examples**

### **Use Docker Examples When:**
- ✅ Developing and testing locally
- ✅ Single-node deployment
- ✅ Quick prototyping
- ✅ Learning AIM Engine basics
- ✅ Limited resources

### **Use Kubernetes Examples When:**
- ✅ Production deployments
- ✅ Multi-node clusters
- ✅ High availability requirements
- ✅ Automatic scaling needs
- ✅ Advanced monitoring and observability

---

## **📚 Additional Resources**

- [AIM Engine Documentation](../README.md)
- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Flask Documentation](https://flask.palletsprojects.com/)

---

**Happy building! 🚀** 