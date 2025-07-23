#!/usr/bin/env python3
"""
Simple Agent Example using AIM Engine vLLM Endpoint
This demonstrates a basic conversational agent that uses the model endpoint.
"""

import requests
import json
import time
from typing import List, Dict, Optional

class SimpleAgent:
    def __init__(self, endpoint_url: str = "http://localhost:8000/v1"):
        """
        Initialize the agent with the AIM Engine endpoint
        
        Args:
            endpoint_url: URL of the vLLM OpenAI-compatible endpoint
        """
        self.endpoint_url = endpoint_url
        self.conversation_history = []
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
    
    def add_message(self, role: str, content: str):
        """Add a message to the conversation history"""
        self.conversation_history.append({
            "role": role,
            "content": content
        })
    
    def chat(self, message: str, system_prompt: str = None) -> str:
        """
        Send a message to the agent and get a response
        
        Args:
            message: User message
            system_prompt: Optional system prompt to guide the agent
            
        Returns:
            Agent's response
        """
        # Add user message to history
        self.add_message("user", message)
        
        # Prepare messages for the API
        messages = []
        
        # Add system prompt if provided
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        # Add conversation history
        messages.extend(self.conversation_history)
        
        # Prepare the API request
        payload = {
            "model": self.model_name,  # Use the detected model name
            "messages": messages,
            "max_tokens": 1000,
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
                
                # Add assistant response to history
                self.add_message("assistant", assistant_message)
                
                return assistant_message
            else:
                return f"Error: {response.status_code} - {response.text}"
                
        except requests.exceptions.RequestException as e:
            return f"Connection error: {str(e)}"
    
    def clear_history(self):
        """Clear the conversation history"""
        self.conversation_history = []
    
    def get_history(self) -> List[Dict]:
        """Get the conversation history"""
        return self.conversation_history.copy()

def main():
    """Example usage of the SimpleAgent"""
    
    # Initialize the agent
    agent = SimpleAgent()
    
    # Example system prompt for a helpful assistant
    system_prompt = """You are a helpful AI assistant. You provide clear, accurate, and helpful responses to user questions. 
    You can help with various tasks including coding, analysis, writing, and general knowledge questions."""
    
    print("🤖 Simple Agent Example")
    print("=" * 50)
    print(f"Using model: {agent.model_name}")
    print("Type 'quit' to exit, 'clear' to clear history")
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
            elif not user_input:
                continue
            
            print("Agent: ", end="", flush=True)
            response = agent.chat(user_input, system_prompt)
            print(response)
            print()
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main() 