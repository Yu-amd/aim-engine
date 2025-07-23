# 🤖 AIM Engine Agent Examples

This directory contains various agent-based applications that use the AIM Engine vLLM endpoint for intelligent interactions.

## 📋 Prerequisites

### 1. AIM Engine Setup
First, make sure your AIM Engine is running:

```bash
# Build the combined container
./build-aim-vllm.sh

# Start the vLLM server with a model
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-serve Qwen/Qwen3-32B
```

### 2. Python Dependencies
Install required packages:

```bash
pip install requests flask
```

## 🚀 Available Examples

### 1. Simple Agent (`simple_agent.py`)
A basic conversational agent with conversation history.

**Features:**
- ✅ Basic chat functionality
- ✅ Conversation history
- ✅ System prompts
- ✅ Error handling

**Usage:**
```bash
python3 examples/simple_agent.py
```

**Example Interaction:**
```
🤖 Simple Agent Example
==================================================
Type 'quit' to exit, 'clear' to clear history

You: What is the capital of France?
Agent: The capital of France is Paris. It's a beautiful city known for its rich history, culture, and iconic landmarks like the Eiffel Tower.

You: Tell me more about it
Agent: Paris is the capital and largest city of France, located in the north-central part of the country. It's known as the "City of Light" and is famous for its art, fashion, gastronomy, and culture. The city is home to many iconic landmarks including the Eiffel Tower, Louvre Museum, Notre-Dame Cathedral, and the Arc de Triomphe.
```

### 2. Advanced Agent (`advanced_agent.py`)
An agent with tools, memory, and structured reasoning.

**Features:**
- ✅ Tool integration (calculator, file reader, time)
- ✅ Memory system with relevance matching
- ✅ Structured tool calling
- ✅ Enhanced system prompts

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
🤖 Advanced Agent Example
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
A beautiful web interface for the agent.

**Features:**
- ✅ Modern web UI with real-time chat
- ✅ Connection status monitoring
- ✅ Mobile-responsive design
- ✅ Session management

**Usage:**
```bash
python3 examples/web_agent.py
```

Then open your browser to `http://localhost:5000`

## 🛠️ Customization

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

## 🔧 Troubleshooting

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

## 🎯 Use Cases

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

**Happy building! 🚀** 