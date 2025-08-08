#!/usr/bin/env python3
"""
Multi-Model AIM Client for Kubernetes
This client demonstrates how to interact with multiple AIMs deployed in Kubernetes.
"""

import requests
import json
import time
import sys
from typing import Dict, List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

class MultiModelAIMClient:
    def __init__(self):
        self.aims = {}
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'Multi-AIM-Client/1.0'
        })
    
    def add_aim(self, name: str, base_url: str):
        """Add an AIM to the client."""
        self.aims[name] = {
            'base_url': base_url,
            'healthy': False,
            'models': []
        }
    
    def health_check_all(self) -> Dict[str, bool]:
        """Check health of all AIMs."""
        results = {}
        
        def check_health(name, base_url):
            try:
                response = self.session.get(f"{base_url}/health", timeout=10)
                healthy = response.status_code == 200
                self.aims[name]['healthy'] = healthy
                return name, healthy
            except requests.RequestException:
                self.aims[name]['healthy'] = False
                return name, False
        
        with ThreadPoolExecutor(max_workers=len(self.aims)) as executor:
            futures = [
                executor.submit(check_health, name, aim['base_url'])
                for name, aim in self.aims.items()
            ]
            
            for future in as_completed(futures):
                name, healthy = future.result()
                results[name] = healthy
        
        return results
    
    def get_models_all(self) -> Dict[str, List[Dict]]:
        """Get models from all AIMs."""
        results = {}
        
        def get_models(name, base_url):
            try:
                response = self.session.get(f"{base_url}/v1/models", timeout=10)
                if response.status_code == 200:
                    models = response.json().get('data', [])
                    self.aims[name]['models'] = models
                    return name, models
                else:
                    return name, []
            except requests.RequestException:
                return name, []
        
        with ThreadPoolExecutor(max_workers=len(self.aims)) as executor:
            futures = [
                executor.submit(get_models, name, aim['base_url'])
                for name, aim in self.aims.items()
            ]
            
            for future in as_completed(futures):
                name, models = future.result()
                results[name] = models
        
        return results
    
    def chat_completion(self, aim_name: str, messages: List[Dict], 
                       model: str = "Qwen/Qwen2.5-7B-Instruct",
                       max_tokens: int = 100, temperature: float = 0.7) -> Optional[Dict]:
        """Send a chat completion request to a specific AIM."""
        if aim_name not in self.aims:
            print(f"❌ AIM '{aim_name}' not found")
            return None
        
        if not self.aims[aim_name]['healthy']:
            print(f"❌ AIM '{aim_name}' is not healthy")
            return None
        
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False
        }
        
        try:
            response = self.session.post(
                f"{self.aims[aim_name]['base_url']}/v1/chat/completions",
                json=payload,
                timeout=30
            )
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Chat completion failed for {aim_name}: {response.status_code}")
                return None
        except requests.RequestException as e:
            print(f"Error in chat completion for {aim_name}: {e}")
            return None
    
    def compare_models(self, messages: List[Dict], question: str) -> Dict[str, str]:
        """Compare responses from all AIMs for the same question."""
        results = {}
        
        def get_response(aim_name):
            response = self.chat_completion(aim_name, messages)
            if response and 'choices' in response:
                return aim_name, response['choices'][0]['message']['content']
            else:
                return aim_name, "❌ Failed to get response"
        
        with ThreadPoolExecutor(max_workers=len(self.aims)) as executor:
            futures = [
                executor.submit(get_response, name)
                for name in self.aims.keys()
            ]
            
            for future in as_completed(futures):
                aim_name, content = future.result()
                results[aim_name] = content
        
        return results

def main():
    print("🚀 Multi-Model AIM Client for Kubernetes")
    print("=" * 50)
    
    # Initialize client
    client = MultiModelAIMClient()
    
    # Add AIMs (you'll need to set up port forwarding for each)
    print("Setting up AIM connections...")
    print("Note: You need to set up port forwarding for each AIM:")
    print("  kubectl port-forward svc/qwen-aim 8000:8000 -n aim-engine")
    print("  kubectl port-forward svc/llama-aim 8001:8000 -n aim-engine")
    print("  kubectl port-forward svc/mistral-aim 8002:8000 -n aim-engine")
    print()
    
    # Add AIMs based on what's available
    client.add_aim("qwen", "http://localhost:8000")
    client.add_aim("llama", "http://localhost:8001")
    client.add_aim("mistral", "http://localhost:8002")
    
    # Check health of all AIMs
    print("Checking AIM health...")
    health_results = client.health_check_all()
    
    healthy_aims = []
    for name, healthy in health_results.items():
        status = "✅" if healthy else "❌"
        print(f"  {status} {name}: {'Healthy' if healthy else 'Unhealthy'}")
        if healthy:
            healthy_aims.append(name)
    
    if not healthy_aims:
        print("❌ No healthy AIMs found. Please check:")
        print("   1. AIMs are deployed and running")
        print("   2. Port forwarding is set up correctly")
        print("   3. AIM pods are in Running state")
        sys.exit(1)
    
    print(f"✅ Found {len(healthy_aims)} healthy AIM(s)")
    
    # Get models from all AIMs
    print("\nGetting available models...")
    models_results = client.get_models_all()
    
    for name, models in models_results.items():
        if models:
            print(f"  📚 {name}:")
            for model in models:
                print(f"    - {model.get('id', 'Unknown')}")
        else:
            print(f"  ❌ {name}: No models available")
    
    # Interactive comparison loop
    print("\n💬 Starting interactive comparison (type 'quit' to exit)")
    print("Commands: 'compare', 'single', 'list', 'clear'")
    print("-" * 50)
    
    messages = []
    
    while True:
        try:
            user_input = input("\nYou: ").strip()
            
            if user_input.lower() == 'quit':
                print("👋 Goodbye!")
                break
            
            if user_input.lower() == 'list':
                print("📋 Available AIMs:")
                for name in healthy_aims:
                    print(f"  - {name}")
                continue
            
            if user_input.lower() == 'clear':
                messages = []
                print("🧹 Conversation history cleared")
                continue
            
            if user_input.lower() == 'compare':
                if not messages:
                    print("❌ No conversation history. Ask a question first.")
                    continue
                
                print("🔄 Comparing responses from all AIMs...")
                results = client.compare_models(messages, user_input)
                
                for aim_name, response in results.items():
                    print(f"\n🤖 {aim_name.upper()}:")
                    print(f"   {response}")
                continue
            
            if user_input.lower() == 'single':
                if not healthy_aims:
                    print("❌ No healthy AIMs available")
                    continue
                
                print(f"Available AIMs: {', '.join(healthy_aims)}")
                aim_choice = input("Choose AIM: ").strip().lower()
                
                if aim_choice not in healthy_aims:
                    print(f"❌ AIM '{aim_choice}' not available")
                    continue
                
                if not messages:
                    print("❌ No conversation history. Ask a question first.")
                    continue
                
                print(f"🤖 Getting response from {aim_choice}...")
                response = client.chat_completion(aim_choice, messages)
                if response and 'choices' in response:
                    content = response['choices'][0]['message']['content']
                    print(f"   {content}")
                    messages.append(response['choices'][0]['message'])
                else:
                    print("❌ Failed to get response")
                continue
            
            if not user_input:
                continue
            
            # Add user message
            messages.append({"role": "user", "content": user_input})
            
            # Get response from first available AIM
            if healthy_aims:
                first_aim = healthy_aims[0]
                print(f"🤖 {first_aim.upper()}: ", end='', flush=True)
                
                response = client.chat_completion(first_aim, messages)
                if response and 'choices' in response:
                    content = response['choices'][0]['message']['content']
                    print(content)
                    messages.append(response['choices'][0]['message'])
                else:
                    print("❌ Failed to get response")
            else:
                print("❌ No healthy AIMs available")
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main() 