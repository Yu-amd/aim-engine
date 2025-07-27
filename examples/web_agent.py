#!/usr/bin/env python3
"""
Web-Based Agent Interface using AIM Engine vLLM Endpoint
This provides a web interface for interacting with the agent.
"""

from flask import Flask, render_template, request, jsonify, session
import requests
import json
import uuid
from datetime import datetime
import os

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'  # Change this in production

class WebAgent:
    def __init__(self, endpoint_url: str = "http://localhost:8000/v1"):
        self.endpoint_url = endpoint_url
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
    
    def chat_stream(self, messages: list, system_prompt: str = None):
        """
        Stream chat response using Server-Sent Events
        
        Args:
            messages: List of message dictionaries
            system_prompt: Optional system prompt
            
        Yields:
            SSE formatted data chunks
        """
        # Prepare messages for API
        api_messages = []
        
        if system_prompt:
            api_messages.append({"role": "system", "content": system_prompt})
        
        api_messages.extend(messages)
        
        payload = {
            "model": self.model_name,
            "messages": api_messages,
            "max_tokens": 1000,
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
                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            data = line[6:]  # Remove 'data: ' prefix
                            
                            if data == '[DONE]':
                                yield f"data: [DONE]\n\n"
                                break
                            
                            try:
                                chunk = json.loads(data)
                                if 'choices' in chunk and len(chunk['choices']) > 0:
                                    delta = chunk['choices'][0].get('delta', {})
                                    if 'content' in delta:
                                        content = delta['content']
                                        # Escape content for SSE
                                        escaped_content = content.replace('\n', '\\n').replace('"', '\\"')
                                        yield f"data: {{\"content\": \"{escaped_content}\"}}\n\n"
                            except json.JSONDecodeError:
                                continue
            else:
                error_msg = f"API Error: {response.status_code} - {response.text}"
                yield f"data: {{\"error\": \"{error_msg}\"}}\n\n"
                
        except requests.exceptions.RequestException as e:
            error_msg = f"Connection error: {str(e)}"
            yield f"data: {{\"error\": \"{error_msg}\"}}\n\n"

    def chat(self, messages: list, system_prompt: str = None) -> dict:
        """
        Send messages to the agent
        
        Args:
            messages: List of message dictionaries
            system_prompt: Optional system prompt
            
        Returns:
            Response dictionary
        """
        # Prepare messages for API
        api_messages = []
        
        if system_prompt:
            api_messages.append({"role": "system", "content": system_prompt})
        
        api_messages.extend(messages)
        
        payload = {
            "model": self.model_name,
            "messages": api_messages,
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
                return {
                    "success": True,
                    "message": result["choices"][0]["message"]["content"],
                    "usage": result.get("usage", {})
                }
            else:
                return {
                    "success": False,
                    "error": f"API Error: {response.status_code} - {response.text}"
                }
                
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"Connection error: {str(e)}"
            }

# Initialize agent
agent = WebAgent()

@app.route('/')
def index():
    """Main chat interface"""
    if 'session_id' not in session:
        session['session_id'] = str(uuid.uuid4())
    
    return render_template('chat.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    """API endpoint for chat (non-streaming)"""
    try:
        data = request.get_json()
        user_message = data.get('message', '').strip()
        conversation_history = data.get('history', [])
        system_prompt = data.get('system_prompt', None)
        
        if not user_message:
            return jsonify({"success": False, "error": "Empty message"})
        
        # Add user message to history
        messages = conversation_history + [
            {"role": "user", "content": user_message}
        ]
        
        # Get response from agent
        response = agent.chat(messages, system_prompt)
        
        if response["success"]:
            # Add assistant response to history
            messages.append({"role": "assistant", "content": response["message"]})
            
            return jsonify({
                "success": True,
                "message": response["message"],
                "history": messages,
                "usage": response.get("usage", {})
            })
        else:
            return jsonify(response)
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

@app.route('/api/chat/stream', methods=['POST'])
def chat_stream():
    """API endpoint for streaming chat using Server-Sent Events"""
    try:
        data = request.get_json()
        user_message = data.get('message', '').strip()
        conversation_history = data.get('history', [])
        system_prompt = data.get('system_prompt', None)
        
        if not user_message:
            return jsonify({"success": False, "error": "Empty message"})
        
        # Add user message to history
        messages = conversation_history + [
            {"role": "user", "content": user_message}
        ]
        
        def generate():
            # Set headers for Server-Sent Events
            yield "data: {\"type\": \"start\"}\n\n"
            
            # Stream the response
            for chunk in agent.chat_stream(messages, system_prompt):
                yield chunk
            
            # Add assistant response to history
            # Note: We'll need to collect the full response for history
            yield "data: {\"type\": \"end\"}\n\n"
        
        return app.response_class(
            generate(),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

@app.route('/api/clear', methods=['POST'])
def clear_history():
    """Clear conversation history"""
    return jsonify({"success": True, "message": "History cleared"})

@app.route('/api/status')
def status():
    """Check if the AIM Engine endpoint is available"""
    try:
        response = requests.get(f"{agent.endpoint_url}/models", timeout=5)
        if response.status_code == 200:
            return jsonify({"success": True, "status": "connected"})
        else:
            return jsonify({"success": False, "status": "error", "message": f"HTTP {response.status_code}"})
    except Exception as e:
        return jsonify({"success": False, "status": "disconnected", "message": str(e)})

# Ensure templates directory exists
os.makedirs('templates', exist_ok=True)

if __name__ == '__main__':
    import socket
    
    # Get local IP addresses for display
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print("Starting Web Agent Interface (with Streaming)...")
    print("Make sure your AIM Engine endpoint is running on http://localhost:8000")
    print("Web interface will be available at:")
    print(f"   - Local: http://localhost:5001")
    print(f"   - Network: http://{local_ip}:5001")
    print()
    print("Features: Real-time streaming responses for better UX")
    print("For remote access:")
    print("   - Same network: Use the Network URL above")
    print("   - SSH tunnel: ssh -L 5001:localhost:5001 user@remote-host")
    print("   - Then access: http://localhost:5001 on your local machine")
    print()
    
    app.run(debug=True, host='0.0.0.0', port=5001) 