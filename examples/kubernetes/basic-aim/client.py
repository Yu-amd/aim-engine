#!/usr/bin/env python3
"""
Basic AIM Client for Kubernetes
This client demonstrates how to interact with an AIM deployed in Kubernetes.
"""

import requests
import json
import time
import sys
from typing import Dict, List, Optional

class AIMClient:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'AIM-Client/1.0'
        })
    
    def health_check(self) -> bool:
        """Check if the AIM is healthy."""
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=10)
            return response.status_code == 200
        except requests.RequestException as e:
            print(f"Health check failed: {e}")
            return False
    
    def get_models(self) -> Optional[List[Dict]]:
        """Get available models from the AIM."""
        try:
            response = self.session.get(f"{self.base_url}/v1/models", timeout=10)
            if response.status_code == 200:
                return response.json().get('data', [])
            else:
                print(f"Failed to get models: {response.status_code}")
                return None
        except requests.RequestException as e:
            print(f"Error getting models: {e}")
            return None
    
    def chat_completion(self, messages: List[Dict], model: str = "Qwen/Qwen2.5-7B-Instruct", 
                       max_tokens: int = 100, temperature: float = 0.7) -> Optional[Dict]:
        """Send a chat completion request to the AIM."""
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=30
            )
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Chat completion failed: {response.status_code}")
                print(f"Response: {response.text}")
                return None
        except requests.RequestException as e:
            print(f"Error in chat completion: {e}")
            return None
    
    def stream_chat_completion(self, messages: List[Dict], model: str = "Qwen/Qwen2.5-7B-Instruct",
                              max_tokens: int = 100, temperature: float = 0.7):
        """Send a streaming chat completion request to the AIM."""
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": True
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=30,
                stream=True
            )
            
            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            data = line[6:]  # Remove 'data: ' prefix
                            if data == '[DONE]':
                                break
                            try:
                                chunk = json.loads(data)
                                if 'choices' in chunk and chunk['choices']:
                                    delta = chunk['choices'][0].get('delta', {})
                                    if 'content' in delta:
                                        print(delta['content'], end='', flush=True)
                            except json.JSONDecodeError:
                                continue
                print()  # New line after streaming
            else:
                print(f"Streaming chat completion failed: {response.status_code}")
        except requests.RequestException as e:
            print(f"Error in streaming chat completion: {e}")

def main():
    print("🚀 Basic AIM Client for Kubernetes")
    print("=" * 50)
    
    # Initialize client
    client = AIMClient()
    
    # Check AIM health
    print("Checking AIM health...")
    if not client.health_check():
        print("❌ AIM is not healthy. Please check:")
        print("   1. AIM is deployed and running")
        print("   2. Port forwarding is set up: kubectl port-forward svc/basic-aim 8000:8000 -n aim-engine")
        print("   3. AIM pod is in Running state")
        sys.exit(1)
    
    print("✅ AIM is healthy!")
    
    # Get available models
    print("\nGetting available models...")
    models = client.get_models()
    if models:
        print("✅ Available models:")
        for model in models:
            print(f"   - {model.get('id', 'Unknown')}")
    else:
        print("❌ No models available")
        sys.exit(1)
    
    # Interactive chat loop
    print("\n💬 Starting interactive chat (type 'quit' to exit, 'stream' to toggle streaming)")
    print("-" * 50)
    
    messages = []
    use_streaming = False
    
    while True:
        try:
            user_input = input("\nYou: ").strip()
            
            if user_input.lower() == 'quit':
                print("👋 Goodbye!")
                break
            
            if user_input.lower() == 'stream':
                use_streaming = not use_streaming
                print(f"🔄 Streaming {'enabled' if use_streaming else 'disabled'}")
                continue
            
            if user_input.lower() == 'clear':
                messages = []
                print("🧹 Conversation history cleared")
                continue
            
            if not user_input:
                continue
            
            # Add user message
            messages.append({"role": "user", "content": user_input})
            
            # Get response
            print("AIM: ", end='', flush=True)
            
            if use_streaming:
                client.stream_chat_completion(messages)
            else:
                response = client.chat_completion(messages)
                if response and 'choices' in response:
                    content = response['choices'][0]['message']['content']
                    print(content)
                else:
                    print("❌ Failed to get response")
                    continue
            
            # Add assistant message to history
            if response and 'choices' in response:
                messages.append(response['choices'][0]['message'])
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main() 