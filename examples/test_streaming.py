#!/usr/bin/env python3
"""
Test script to demonstrate streaming functionality in AIM Engine agents
"""

import requests
import json
import time

def test_simple_agent_streaming():
    """Test the simple agent with streaming"""
    print("🧪 Testing Simple Agent Streaming...")
    print("=" * 50)
    
    # Test the streaming endpoint directly
    payload = {
        "model": "Qwen/Qwen3-32B",  # Adjust model name as needed
        "messages": [
            {"role": "user", "content": "Tell me a short story about a robot learning to paint."}
        ],
        "max_tokens": 200,
        "temperature": 0.7,
        "stream": True
    }
    
    try:
        response = requests.post(
            "http://localhost:8000/v1/chat/completions",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30,
            stream=True
        )
        
        if response.status_code == 200:
            print("🤖 Streaming response:")
            print("Agent: ", end="", flush=True)
            
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
                                    print(content, end='', flush=True)
                        except json.JSONDecodeError:
                            continue
            
            print("\n✅ Streaming test completed successfully!")
        else:
            print(f"❌ Error: {response.status_code} - {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {str(e)}")

def test_web_agent_streaming():
    """Test the web agent streaming endpoint"""
    print("\n🌐 Testing Web Agent Streaming...")
    print("=" * 50)
    
    payload = {
        "message": "What is the capital of France?",
        "history": [],
        "system_prompt": "You are a helpful AI assistant."
    }
    
    try:
        response = requests.post(
            "http://localhost:5000/api/chat/stream",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30,
            stream=True
        )
        
        if response.status_code == 200:
            print("🤖 Web agent streaming response:")
            print("Agent: ", end="", flush=True)
            
            for line in response.iter_lines():
                if line:
                    line = line.decode('utf-8')
                    if line.startswith('data: '):
                        data = line[6:]  # Remove 'data: ' prefix
                        
                        if data == '[DONE]':
                            break
                        
                        try:
                            chunk = json.loads(data)
                            if 'content' in chunk:
                                content = chunk['content']
                                print(content, end='', flush=True)
                        except json.JSONDecodeError:
                            continue
            
            print("\n✅ Web agent streaming test completed successfully!")
        else:
            print(f"❌ Error: {response.status_code} - {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {str(e)}")

def main():
    """Run streaming tests"""
    print("🚀 AIM Engine Streaming Test Suite")
    print("=" * 60)
    print("This script tests the streaming functionality of AIM Engine agents.")
    print("Make sure your AIM Engine endpoint is running on http://localhost:8000")
    print("and optionally the web agent on http://localhost:5000")
    print()
    
    # Test simple agent streaming
    test_simple_agent_streaming()
    
    # Test web agent streaming (if available)
    try:
        # Check if web agent is running
        status_response = requests.get("http://localhost:5000/api/status", timeout=5)
        if status_response.status_code == 200:
            test_web_agent_streaming()
        else:
            print("\n⚠️  Web agent not running on http://localhost:5000")
            print("   Start it with: python3 web_agent.py")
    except:
        print("\n⚠️  Web agent not running on http://localhost:5000")
        print("   Start it with: python3 web_agent.py")
    
    print("\n🎉 Streaming tests completed!")
    print("\n📝 Usage:")
    print("   - Simple agent: python3 simple_agent.py")
    print("   - Advanced agent: python3 advanced_agent.py")
    print("   - Web agent: python3 web_agent.py")

if __name__ == "__main__":
    main() 