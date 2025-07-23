#!/usr/bin/env python3
"""
Advanced Agent Example using AIM Engine vLLM Endpoint
This demonstrates an agent with tools, memory, and structured reasoning.
"""

import requests
import json
import time
import re
from typing import List, Dict, Optional, Callable, Any
from datetime import datetime
import os

class Tool:
    """Base class for agent tools"""
    
    def __init__(self, name: str, description: str, func: Callable):
        self.name = name
        self.description = description
        self.func = func
    
    def execute(self, *args, **kwargs) -> Any:
        """Execute the tool"""
        return self.func(*args, **kwargs)

class AdvancedAgent:
    def __init__(self, endpoint_url: str = "http://localhost:8000/v1"):
        """
        Initialize the advanced agent
        
        Args:
            endpoint_url: URL of the vLLM OpenAI-compatible endpoint
        """
        self.endpoint_url = endpoint_url
        self.conversation_history = []
        self.tools = {}
        self.memory = []
        self.max_memory_size = 100
        self.model_name = self._get_available_model()
        
    def _get_available_model(self) -> str:
        """Get the first available model from the endpoint"""
        try:
            response = requests.get(f"{self.endpoint_url}/models", timeout=10)
            if response.status_code == 200:
                models = response.json()
                if models.get("data") and len(models["data"]) > 0:
                    return models["data"][0]["id"]
                else:
                    return "Qwen/Qwen3-32B"  # Fallback model name
            else:
                return "Qwen/Qwen3-32B"  # Fallback model name
        except:
            return "Qwen/Qwen3-32B"  # Fallback model name
        
    def add_tool(self, tool: Tool):
        """Add a tool to the agent"""
        self.tools[tool.name] = tool
    
    def add_to_memory(self, content: str, memory_type: str = "general"):
        """Add information to agent memory"""
        memory_entry = {
            "content": content,
            "type": memory_type,
            "timestamp": datetime.now().isoformat()
        }
        self.memory.append(memory_entry)
        
        # Keep memory size manageable
        if len(self.memory) > self.max_memory_size:
            self.memory.pop(0)
    
    def get_relevant_memory(self, query: str, limit: int = 5) -> List[Dict]:
        """Get relevant memory entries based on query (simple keyword matching)"""
        # Simple keyword-based relevance (could be enhanced with embeddings)
        query_words = set(query.lower().split())
        relevant = []
        
        for entry in reversed(self.memory):  # Start from most recent
            content_words = set(entry["content"].lower().split())
            if query_words.intersection(content_words):
                relevant.append(entry)
                if len(relevant) >= limit:
                    break
        
        return relevant
    
    def _create_tool_descriptions(self) -> str:
        """Create descriptions of available tools for the agent"""
        if not self.tools:
            return "No tools available."
        
        descriptions = []
        for name, tool in self.tools.items():
            descriptions.append(f"- {name}: {tool.description}")
        
        return "\n".join(descriptions)
    
    def _extract_tool_calls(self, response: str) -> List[Dict]:
        """Extract tool calls from agent response"""
        tool_calls = []
        
        # Look for patterns like: [TOOL: tool_name(args)]
        pattern = r'\[TOOL:\s*(\w+)\s*\((.*?)\)\]'
        matches = re.findall(pattern, response)
        
        for tool_name, args_str in matches:
            try:
                # Simple argument parsing (could be enhanced)
                args = []
                kwargs = {}
                
                if args_str.strip():
                    # Parse arguments (this is simplified)
                    parts = args_str.split(',')
                    for part in parts:
                        part = part.strip()
                        if '=' in part:
                            key, value = part.split('=', 1)
                            kwargs[key.strip()] = value.strip().strip('"\'')
                        else:
                            args.append(part.strip().strip('"\''))
                
                tool_calls.append({
                    "tool": tool_name,
                    "args": args,
                    "kwargs": kwargs
                })
            except Exception as e:
                print(f"Error parsing tool call: {e}")
        
        return tool_calls
    
    def _execute_tool_calls(self, tool_calls: List[Dict]) -> List[str]:
        """Execute tool calls and return results"""
        results = []
        
        for call in tool_calls:
            tool_name = call["tool"]
            args = call["args"]
            kwargs = call["kwargs"]
            
            if tool_name in self.tools:
                try:
                    result = self.tools[tool_name].execute(*args, **kwargs)
                    results.append(f"Tool {tool_name} result: {result}")
                except Exception as e:
                    results.append(f"Tool {tool_name} error: {str(e)}")
            else:
                results.append(f"Tool {tool_name} not found")
        
        return results
    
    def chat_stream(self, message: str, system_prompt: str = None) -> str:
        """
        Advanced chat with tool usage and memory (streaming version)
        
        Args:
            message: User message
            system_prompt: Optional system prompt
            
        Returns:
            Agent's response
        """
        # Add user message to history
        self.add_message("user", message)
        
        # Get relevant memory
        relevant_memory = self.get_relevant_memory(message)
        memory_context = ""
        if relevant_memory:
            memory_context = "\n\nRelevant memory:\n" + "\n".join([
                f"- {entry['content']}" for entry in relevant_memory
            ])
        
        # Create enhanced system prompt
        enhanced_system_prompt = system_prompt or "You are a helpful AI assistant."
        
        if self.tools:
            tool_descriptions = self._create_tool_descriptions()
            enhanced_system_prompt += f"\n\nYou have access to these tools:\n{tool_descriptions}\n\nTo use a tool, format your response as: [TOOL: tool_name(arg1, arg2, param=value)]"
        
        enhanced_system_prompt += memory_context
        
        # Prepare messages
        messages = [
            {"role": "system", "content": enhanced_system_prompt}
        ]
        messages.extend(self.conversation_history)
        
        # API request for streaming
        payload = {
            "model": self.model_name,
            "messages": messages,
            "max_tokens": 1500,
            "temperature": 0.7,
            "stream": True
        }
        
        try:
            response = requests.post(
                f"{self.endpoint_url}/chat/completions",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30,
                stream=True
            )
            
            if response.status_code == 200:
                full_response = ""
                
                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            data = line[6:]  # Remove 'data: ' prefix
                            
                            if data == '[DONE]':
                                break
                            
                            try:
                                chunk = json.loads(data)
                                if 'choices' in chunk and len(chunk['choices']) > 0:
                                    delta = chunk['choices'][0].get('delta', {})
                                    if 'content' in delta:
                                        content = delta['content']
                                        full_response += content
                                        print(content, end='', flush=True)
                            except json.JSONDecodeError:
                                continue
                
                # Extract and execute tool calls
                tool_calls = self._extract_tool_calls(full_response)
                if tool_calls:
                    print("\n\n🔧 Executing tools...")
                    tool_results = self._execute_tool_calls(tool_calls)
                    
                    # Add tool results to memory
                    for result in tool_results:
                        self.add_to_memory(result, "tool_result")
                    
                    # Display tool results
                    print("\n📋 Tool Results:")
                    for result in tool_results:
                        print(f"  • {result}")
                    
                    # Create final response with tool results
                    final_response = full_response + "\n\n" + "\n".join(tool_results)
                else:
                    final_response = full_response
                
                # Add to conversation history
                self.add_message("assistant", final_response)
                
                # Add to memory
                self.add_to_memory(f"User asked: {message}. Assistant responded: {final_response}")
                
                return final_response
            else:
                error_msg = f"Error: {response.status_code} - {response.text}"
                print(error_msg)
                return error_msg
                
        except requests.exceptions.RequestException as e:
            error_msg = f"Connection error: {str(e)}"
            print(error_msg)
            return error_msg

    def chat(self, message: str, system_prompt: str = None) -> str:
        """
        Advanced chat with tool usage and memory
        
        Args:
            message: User message
            system_prompt: Optional system prompt
            
        Returns:
            Agent's response
        """
        # Add user message to history
        self.add_message("user", message)
        
        # Get relevant memory
        relevant_memory = self.get_relevant_memory(message)
        memory_context = ""
        if relevant_memory:
            memory_context = "\n\nRelevant memory:\n" + "\n".join([
                f"- {entry['content']}" for entry in relevant_memory
            ])
        
        # Create enhanced system prompt
        enhanced_system_prompt = system_prompt or "You are a helpful AI assistant."
        
        if self.tools:
            tool_descriptions = self._create_tool_descriptions()
            enhanced_system_prompt += f"\n\nYou have access to these tools:\n{tool_descriptions}\n\nTo use a tool, format your response as: [TOOL: tool_name(arg1, arg2, param=value)]"
        
        enhanced_system_prompt += memory_context
        
        # Prepare messages
        messages = [
            {"role": "system", "content": enhanced_system_prompt}
        ]
        messages.extend(self.conversation_history)
        
        # API request
        payload = {
            "model": self.model_name,
            "messages": messages,
            "max_tokens": 1500,
            "temperature": 0.7,
            "stream": False
        }
        
        try:
            response = requests.post(
                f"{self.endpoint_url}/chat/completions",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                assistant_message = result["choices"][0]["message"]["content"]
                
                # Extract and execute tool calls
                tool_calls = self._extract_tool_calls(assistant_message)
                if tool_calls:
                    tool_results = self._execute_tool_calls(tool_calls)
                    
                    # Add tool results to memory
                    for result in tool_results:
                        self.add_to_memory(result, "tool_result")
                    
                    # Create final response with tool results
                    final_response = assistant_message + "\n\n" + "\n".join(tool_results)
                else:
                    final_response = assistant_message
                
                # Add to conversation history
                self.add_message("assistant", final_response)
                
                # Add to memory
                self.add_to_memory(f"User asked: {message}. Assistant responded: {final_response}")
                
                return final_response
            else:
                return f"Error: {response.status_code} - {response.text}"
                
        except requests.exceptions.RequestException as e:
            return f"Connection error: {str(e)}"
    
    def add_message(self, role: str, content: str):
        """Add a message to the conversation history"""
        self.conversation_history.append({
            "role": role,
            "content": content
        })
    
    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []
    
    def clear_memory(self):
        """Clear agent memory"""
        self.memory = []
    
    def get_memory_summary(self) -> str:
        """Get a summary of agent memory"""
        if not self.memory:
            return "No memory entries."
        
        summary = f"Memory entries ({len(self.memory)}):\n"
        for i, entry in enumerate(self.memory[-5:], 1):  # Show last 5 entries
            summary += f"{i}. [{entry['type']}] {entry['content'][:100]}...\n"
        
        return summary

# Example tools
def calculator_tool(expression: str) -> str:
    """Simple calculator tool"""
    try:
        # Safe evaluation (only basic math operations)
        allowed_chars = set('0123456789+-*/(). ')
        if not all(c in allowed_chars for c in expression):
            return "Error: Invalid characters in expression"
        
        result = eval(expression)
        return f"Result: {result}"
    except Exception as e:
        return f"Error: {str(e)}"

def file_reader_tool(filename: str) -> str:
    """Read file contents"""
    try:
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                content = f.read()
            return f"File contents:\n{content[:500]}..." if len(content) > 500 else f"File contents:\n{content}"
        else:
            return f"File {filename} not found"
    except Exception as e:
        return f"Error reading file: {str(e)}"

def time_tool() -> str:
    """Get current time"""
    return f"Current time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"

def main():
    """Example usage of the AdvancedAgent"""
    
    # Initialize agent
    agent = AdvancedAgent()
    
    # Add tools
    agent.add_tool(Tool("calculator", "Calculate mathematical expressions", calculator_tool))
    agent.add_tool(Tool("read_file", "Read contents of a file", file_reader_tool))
    agent.add_tool(Tool("get_time", "Get current date and time", time_tool))
    
    # System prompt
    system_prompt = """You are an advanced AI assistant with access to tools and memory. 
    You can perform calculations, read files, and remember previous interactions.
    Use tools when appropriate to help users with their tasks."""
    
    print("🤖 Advanced Agent Example (with Streaming)")
    print("=" * 50)
    print("Commands: 'quit', 'clear', 'memory', 'history'")
    print("Tools available: calculator, read_file, get_time")
    print("Responses will stream in real-time for better UX")
    print()
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if user_input.lower() == 'quit':
                break
            elif user_input.lower() == 'clear':
                agent.clear_history()
                print("Conversation history cleared.")
                continue
            elif user_input.lower() == 'memory':
                print(agent.get_memory_summary())
                continue
            elif user_input.lower() == 'history':
                for msg in agent.conversation_history[-3:]:
                    print(f"{msg['role']}: {msg['content'][:100]}...")
                continue
            elif not user_input:
                continue
            
            print("Agent: ", end="", flush=True)
            response = agent.chat_stream(user_input, system_prompt)
            print() # Print a newline after streaming
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main() 