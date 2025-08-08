#  AIM Engine Examples

This directory contains various examples for using AIM Engine:

## **Docker Examples** (Single Node)
Traditional Docker-based examples for local development and testing.

## **Kubernetes Examples** (Multi-Node)
Modern Kubernetes-based examples using the AIM Engine operator for production deployments.

---

## **Docker Examples**

These examples use the traditional Docker deployment approach for single-node setups.

##  Prerequisites

### 0. Port Requirements
**Important**: All examples require port 8000 to be available for the AIM Engine endpoint.

```bash
# Check if port 8000 is available
netstat -tlnp | grep 8000

# If port 8000 is in use, either:
# 1. Stop the service using port 8000, or
# 2. Use a different port for AIM Engine (update examples accordingly)
```

### 1. AIM Engine Endpoint
Ensure your AIM Engine endpoint is running and ready on port 8000:

```bash
# Test if the endpoint is responding
curl -f http://localhost:8000/health

# Test if models are loaded and ready
curl -f http://localhost:8000/v1/models
```

### 2. Python Dependencies
Install required packages:

```bash
pip install requests flask
```

##  Available Docker Examples

### 1. Simple Agent (`simple_agent.py`)
A basic conversational agent with conversation history and **real-time streaming responses**.

**Features:**
-  Basic chat functionality
-  **Real-time streaming responses** 
-  Conversation history
-  System prompts
-  Error handling

**Usage:**
```bash
python3 examples/simple_agent.py
```

**Example Interaction:**
```
 Simple Agent Example
==================================================
Type 'quit' to exit, 'clear' to clear history

You: What is the capital of France?
Agent: The capital of France is Paris. It's a beautiful city known for its rich history, culture, and iconic landmarks like the Eiffel Tower.

You: Tell me more about it
Agent: Paris is the capital and largest city of France, located in the north-central part of the country. It's known as the "City of Light" and is famous for its art, fashion, gastronomy, and culture. The city is home to many iconic landmarks including the Eiffel Tower, Louvre Museum, Notre-Dame Cathedral, and the Arc de Triomphe.
```

### 2. Advanced Agent (`advanced_agent.py`)
An agent with tools, memory, structured reasoning, and **real-time streaming responses**.

**Features:**
-  Tool integration (calculator, file reader, time)
-  **Real-time streaming responses** 
-  Memory system with relevance matching
-  Structured tool calling
-  Enhanced system prompts

**Usage:**
```bash
python3 examples/advanced_agent.py
```

**Available Tools:**
- `calculator`: Perform mathematical calculations
- `read_file`: Read file contents
- `get_time`: Get current date and time

**Example Interaction:**
```
 Advanced Agent Example
==================================================
Commands: 'quit', 'clear', 'memory', 'history'
Tools available: calculator, read_file, get_time

You: Calculate 15 * 23 + 7
Agent: I'll calculate that for you.

[TOOL: calculator(15 * 23 + 7)]

Tool calculator result: Result: 352

The result of 15 * 23 + 7 is 352.

You: What time is it?
Agent: Let me get the current time for you.

[TOOL: get_time()]

Tool get_time result: Current time: 2024-01-15 14:30:25

The current time is 2024-01-15 14:30:25.
```

### 3. Web Agent (`web_agent.py`)
A beautiful web interface for the agent with **real-time streaming responses**.

**Features:**
-  Modern web UI with real-time chat
-  **Real-time streaming responses** 
-  Connection status monitoring
-  Mobile-responsive design
-  Session management
-  Remote access support

**Usage:**
```bash
python3 examples/web_agent.py
```

The web interface will be available at:
- **Local access**: `http://localhost:5000`
- **Network access**: `http://<remote-ip>:5000`

##  Streaming Features

All agent examples now support **real-time streaming responses** for a better user experience:

###  Benefits of Streaming
- **Faster perceived response time**: Users see responses as they're generated
- **Better engagement**: Real-time feedback keeps users engaged
- **Improved UX**: No waiting for complete responses before seeing content
- **Interactive experience**: Users can see the AI "thinking" in real-time

###  How Streaming Works
1. **Simple Agent**: Uses `chat_stream()` method with real-time console output
2. **Advanced Agent**: Streams responses and shows tool execution in real-time
3. **Web Agent**: Uses Server-Sent Events (SSE) for browser-based streaming

### 🧪 Testing Streaming
Use the included test script to verify streaming functionality:

```bash
cd examples
python3 test_streaming.py
```

This will test both the direct vLLM endpoint and web agent streaming.

##  Remote Access Methods

### Method 1: Direct Network Access (Same Network)
If your local machine and remote node are on the same network:

1. **Get the remote node's IP address:**
   ```bash
   # On the remote node
   hostname -I
   # or
   ip addr show
   ```

2. **Access the web interface:**
   ```
   http://<remote-node-ip>:5000
   ```

### Method 2: SSH Port Forwarding (Recommended)
For secure access through SSH:

1. **Connect with port forwarding:**
   ```bash
   ssh -L 5000:localhost:5000 username@remote-node
   ```

2. **Access on your local machine:**
   ```
   http://localhost:5000
   ```

### Method 3: Reverse SSH Tunnel (Behind Firewall)
If the remote node is behind a firewall:

1. **On the remote node, create reverse tunnel:**
   ```bash
   ssh -R 5000:localhost:5000 username@your-laptop-ip
   ```

2. **Access on your local machine:**
   ```
   http://localhost:5000
   ```

### Method 4: Using the Quick Start Script
The quick start script handles virtual environment setup automatically:

```bash
cd examples
./quick_start.sh
# Choose option 3 (Web Agent)
```

##  Network Diagnostics

### Diagnostic Tool
Use the included diagnostic tool to troubleshoot network issues:

```bash
cd examples
python3 check_web_access.py
```

This tool will check:
-  Network configuration
-  Port accessibility
-  Firewall status
-  Web agent connectivity
-  AIM Engine endpoint status

### Manual Network Checks

**Check if port 5000 is listening:**
```bash
netstat -tlnp | grep :5000
```

**Check firewall status:**
```bash
sudo ufw status
```

**Allow port 5000 through firewall:**
```bash
sudo ufw allow 5000
```

**Test local connectivity:**
```bash
curl http://localhost:5000
```

##  Common Remote Access Issues

### Issue: "Connection Refused"
**Solution:**
1. Ensure web agent is running with `host='0.0.0.0'`
2. Check if port 5000 is open in firewall
3. Verify the web agent process is running

### Issue: "Page Not Found"
**Solution:**
1. Check if AIM Engine endpoint is running on port 8000
2. Verify the web agent can connect to the AIM Engine
3. Check web agent logs for errors

### Issue: "Slow Response"
**Solution:**
1. Check network latency between machines
2. Monitor AIM Engine performance
3. Consider using SSH port forwarding for better performance

### Issue: "Security Warnings"
**Solution:**
1. Use SSH port forwarding for secure access
2. Consider adding authentication to the web interface
3. Use HTTPS in production environments

## 🛠 Customization

### Adding Custom Tools
You can easily add custom tools to the advanced agent:

```python
def custom_tool(param1: str, param2: int) -> str:
    """Your custom tool description"""
    # Your tool logic here
    return f"Result: {param1} and {param2}"

# Add to agent
agent.add_tool(Tool("custom_tool", "Description of what it does", custom_tool))
```

### Custom System Prompts
Modify the system prompt to change agent behavior:

```python
custom_prompt = """You are a specialized AI assistant for [your domain].
Your role is to [specific behavior].
Always [specific instructions]."""

response = agent.chat(message, custom_prompt)
```

### Endpoint Configuration
Change the endpoint URL if needed:

```python
# For different port or host
agent = SimpleAgent("http://your-host:8000/v1")
```

##  Troubleshooting

### Connection Issues
If you get connection errors:

1. **Check if AIM Engine is running:**
   ```bash
   docker ps | grep aim-vllm
   ```

2. **Check endpoint availability:**
   ```bash
   curl http://localhost:8000/v1/models
   ```

3. **Verify port mapping:**
   ```bash
   netstat -tlnp | grep 8000
   ```

### Model Loading Issues
If the model isn't loading:

1. **Check container logs:**
   ```bash
   docker logs <container_name>
   ```

2. **Verify model cache:**
   ```bash
   ls -la /workspace/model-cache/
   ```

3. **Restart the container:**
   ```bash
   docker stop <container_name>
   docker run ... # (restart command)
   ```

### Performance Optimization
For better performance:

1. **Use appropriate model size** for your hardware
2. **Adjust max_tokens** based on your needs
3. **Consider streaming** for long responses
4. **Implement caching** for repeated queries

##  Use Cases

### 1. Customer Support Agent
```python
system_prompt = """You are a customer support agent for [Company Name].
You help customers with product questions, troubleshooting, and general inquiries.
Always be polite, professional, and helpful."""
```

### 2. Code Assistant
```python
system_prompt = """You are a programming assistant.
You help with code review, debugging, and explaining programming concepts.
Provide clear, well-documented code examples."""
```

### 3. Data Analysis Assistant
```python
system_prompt = """You are a data analysis expert.
You help interpret data, suggest analysis methods, and explain statistical concepts.
Always provide clear explanations and practical insights."""
```

### 4. Educational Tutor
```python
system_prompt = """You are an educational tutor.
You help students understand complex topics through clear explanations and examples.
Adapt your teaching style to the student's level."""
```

## 🔒 Security Considerations

1. **Input Validation**: Always validate user inputs
2. **Rate Limiting**: Implement rate limiting for production use
3. **Authentication**: Add authentication for web interfaces
4. **Tool Safety**: Ensure tools are safe and don't expose sensitive data
5. **Error Handling**: Don't expose internal errors to users

## 📈 Scaling Considerations

### For Production Use:
1. **Load Balancing**: Use multiple AIM Engine instances
2. **Caching**: Implement response caching
3. **Monitoring**: Add logging and metrics
4. **Database**: Store conversations in a database
5. **Queue System**: Use message queues for high load

### Performance Monitoring:
```python
import time

start_time = time.time()
response = agent.chat(message)
end_time = time.time()

print(f"Response time: {end_time - start_time:.2f} seconds")
```

## 🤝 Contributing

To add new agent examples:

1. Create a new Python file in the `examples/` directory
2. Follow the existing code structure
3. Add comprehensive documentation
4. Include error handling
5. Test with different models

## 📚 Additional Resources

- [AIM Engine Documentation](../README.md)
- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Flask Documentation](https://flask.palletsprojects.com/)

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

**Happy building! ** 