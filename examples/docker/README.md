# AIM Docker Examples

This directory contains various agent-based applications that use AIM (AMD Inference Microservice) endpoints for intelligent interactions in a Docker environment.

## Prerequisites

### 0. Port Requirements
**Important**: All examples require port 8000 to be available for the AIM endpoint.

```bash
# Check if port 8000 is available
netstat -tlnp | grep 8000

# If port 8000 is in use, either:
# 1. Stop the service using port 8000, or
# 2. Use a different port for AIM (update examples accordingly)
```

### 1. Python Dependencies
Install required packages:

```bash
pip install requests flask
```

## Setup AIM Endpoint

### Start AIM
Before running any examples, you need to start an AIM endpoint:

```bash
# Launch model with auto-detection
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B

# Start interactive shell
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell
```

### Verify AIM is Running
Ensure your AIM (AMD Inference Microservice) endpoint is running and ready on port 8000:

```bash
# Test if the endpoint is responding
curl -f http://localhost:8000/health

# Test if models are loaded and ready
curl -f http://localhost:8000/v1/models

# Test a simple inference request
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

## Available Examples

### 1. Simple Agent (`simple_agent.py`)
A basic conversational agent with conversation history and **real-time streaming responses**.

**Features:**
- Basic chat functionality
- **Real-time streaming responses** 
- Conversation history
- System prompts
- Error handling

**Usage:**
```bash
python3 docker/simple_agent.py
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
- Tool integration (calculator, file reader, time)
- **Real-time streaming responses** 
- Memory system with relevance matching
- Structured tool calling
- Enhanced system prompts

**Usage:**
```bash
python3 docker/advanced_agent.py
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
```

### 3. Web Agent (`web_agent.py`)
A web-based agent with Flask interface for browser interaction.

**Features:**
- Web interface for chat
- Real-time streaming responses
- Conversation history
- Tool integration
- RESTful API endpoints

**Usage:**
```bash
python3 docker/web_agent.py
```

**Access:**
- Web interface: http://localhost:5000
- API endpoint: http://localhost:5000/api/chat

### 4. Test Streaming (`test_streaming.py`)
Test script for streaming responses from AIM.

**Features:**
- Streaming response testing
- Performance measurement
- Error handling
- Response validation

**Usage:**
```bash
python3 docker/test_streaming.py
```

### 5. Check Web Access (`check_web_access.py`)
Utility to check web access and connectivity.

**Features:**
- Web connectivity testing
- URL validation
- Response analysis
- Error reporting

**Usage:**
```bash
python3 docker/check_web_access.py
```

### 6. Quick Start Script (`quick_start.sh`)
Automated setup and testing script.

**Features:**
- Automated AIM setup
- Health checks
- Model loading verification
- Example interactions

**Usage:**
```bash
./docker/quick_start.sh
```

## Quick Start Workflow

1. **Start AIM Endpoint**:
   ```bash
   docker run --rm -it \
     --device=/dev/kfd \
     --device=/dev/dri \
     --group-add=video \
     --group-add=render \
     -v /workspace/model-cache:/workspace/model-cache \
     -p 8000:8000 \
     aim-vllm:latest \
     aim-shell
   ```

2. **Verify AIM is Running**:
   ```bash
   curl -f http://localhost:8000/health
   ```

3. **Run an Example**:
   ```bash
   python3 docker/simple_agent.py
   ```

## Troubleshooting

### Common Issues

1. **Port 8000 in use**
   ```bash
   # Find what's using port 8000
   netstat -tlnp | grep 8000
   
   # Stop the conflicting service
   sudo systemctl stop <service-name>
   ```

2. **Docker permission issues**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   
   # Restart shell or logout/login
   ```

3. **GPU not detected**
   ```bash
   # Check GPU status
   rocm-smi
   
   # Check Docker GPU access
   docker run --rm --device=/dev/kfd --device=/dev/dri rocm/dev-ubuntu-20.04 rocm-smi
   ```

4. **Model loading issues**
   ```bash
   # Check model cache
   ls -la /workspace/model-cache/
   
   # Clear cache if needed
   rm -rf /workspace/model-cache/*
   ```

5. **AIM not responding**
   ```bash
   # Check if AIM container is running
   docker ps | grep aim-vllm
   
   # Check AIM logs
   docker logs <container-name>
   
   # Restart AIM if needed
   docker stop <container-name>
   docker run ... # (restart command)
   ```

### Performance Optimization
For better performance:

1. **Use appropriate model size** for your hardware
2. **Adjust max_tokens** based on your needs
3. **Consider streaming** for long responses
4. **Implement caching** for repeated queries

## Use Cases

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
1. **Load Balancing**: Use multiple AIM instances
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

1. Create a new Python file in the `docker/` directory
2. Follow the existing code structure
3. Add comprehensive documentation
4. Include error handling
5. Test with different models

## 📚 Additional Resources

- [AIM Engine Documentation](../../README.md)
- [Kubernetes Examples](../kubernetes/README.md)
- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Flask Documentation](https://flask.palletsprojects.com/)

---

**Happy building! 🚀** 