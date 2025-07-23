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
    """API endpoint for chat"""
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

# Create templates directory and HTML template
os.makedirs('templates', exist_ok=True)

@app.route('/templates/chat.html')
def chat_template():
    """Serve the chat template"""
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AIM Engine Agent</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 1rem;
            text-align: center;
            color: white;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .chat-container {
            flex: 1;
            max-width: 800px;
            margin: 0 auto;
            width: 100%;
            display: flex;
            flex-direction: column;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            margin: 1rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .chat-messages {
            flex: 1;
            overflow-y: auto;
            padding: 1rem;
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }
        
        .message {
            display: flex;
            align-items: flex-start;
            gap: 0.5rem;
            animation: fadeIn 0.3s ease-in;
        }
        
        .message.user {
            flex-direction: row-reverse;
        }
        
        .message-content {
            max-width: 70%;
            padding: 0.75rem 1rem;
            border-radius: 1rem;
            word-wrap: break-word;
        }
        
        .message.user .message-content {
            background: #667eea;
            color: white;
            border-bottom-right-radius: 0.25rem;
        }
        
        .message.assistant .message-content {
            background: #f1f3f4;
            color: #333;
            border-bottom-left-radius: 0.25rem;
        }
        
        .avatar {
            width: 2rem;
            height: 2rem;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: white;
        }
        
        .user .avatar {
            background: #667eea;
        }
        
        .assistant .avatar {
            background: #34a853;
        }
        
        .input-container {
            padding: 1rem;
            border-top: 1px solid #e0e0e0;
            display: flex;
            gap: 0.5rem;
        }
        
        .message-input {
            flex: 1;
            padding: 0.75rem;
            border: 2px solid #e0e0e0;
            border-radius: 1.5rem;
            outline: none;
            font-size: 1rem;
            transition: border-color 0.3s;
        }
        
        .message-input:focus {
            border-color: #667eea;
        }
        
        .send-button {
            padding: 0.75rem 1.5rem;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 1.5rem;
            cursor: pointer;
            font-size: 1rem;
            transition: background 0.3s;
        }
        
        .send-button:hover {
            background: #5a6fd8;
        }
        
        .send-button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        
        .status-bar {
            padding: 0.5rem 1rem;
            background: #f8f9fa;
            border-top: 1px solid #e0e0e0;
            font-size: 0.875rem;
            color: #666;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 0.25rem;
        }
        
        .status-dot {
            width: 0.5rem;
            height: 0.5rem;
            border-radius: 50%;
            background: #ccc;
        }
        
        .status-dot.connected {
            background: #34a853;
        }
        
        .status-dot.disconnected {
            background: #ea4335;
        }
        
        .clear-button {
            background: none;
            border: none;
            color: #667eea;
            cursor: pointer;
            font-size: 0.875rem;
        }
        
        .clear-button:hover {
            text-decoration: underline;
        }
        
        .typing-indicator {
            display: none;
            padding: 0.75rem 1rem;
            background: #f1f3f4;
            border-radius: 1rem;
            border-bottom-left-radius: 0.25rem;
            color: #666;
            font-style: italic;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        @media (max-width: 768px) {
            .chat-container {
                margin: 0.5rem;
                border-radius: 0;
            }
            
            .message-content {
                max-width: 85%;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🤖 AIM Engine Agent</h1>
        <p>Powered by vLLM ROCm</p>
    </div>
    
    <div class="chat-container">
        <div class="chat-messages" id="chatMessages">
            <div class="message assistant">
                <div class="avatar">AI</div>
                <div class="message-content">
                    Hello! I'm your AI assistant powered by the AIM Engine. How can I help you today?
                </div>
            </div>
        </div>
        
        <div class="typing-indicator" id="typingIndicator">
            AI is thinking...
        </div>
        
        <div class="input-container">
            <input type="text" id="messageInput" class="message-input" placeholder="Type your message..." autocomplete="off">
            <button id="sendButton" class="send-button">Send</button>
        </div>
        
        <div class="status-bar">
            <div class="status-indicator">
                <div class="status-dot" id="statusDot"></div>
                <span id="statusText">Checking connection...</span>
            </div>
            <button class="clear-button" id="clearButton">Clear History</button>
        </div>
    </div>
    
    <script>
        let conversationHistory = [];
        let isTyping = false;
        
        const chatMessages = document.getElementById('chatMessages');
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');
        const typingIndicator = document.getElementById('typingIndicator');
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        const clearButton = document.getElementById('clearButton');
        
        // Check connection status
        async function checkStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                if (data.success) {
                    statusDot.className = 'status-dot connected';
                    statusText.textContent = 'Connected';
                } else {
                    statusDot.className = 'status-dot disconnected';
                    statusText.textContent = 'Disconnected';
                }
            } catch (error) {
                statusDot.className = 'status-dot disconnected';
                statusText.textContent = 'Connection Error';
            }
        }
        
        // Add message to chat
        function addMessage(content, role) {
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${role}`;
            
            const avatar = document.createElement('div');
            avatar.className = 'avatar';
            avatar.textContent = role === 'user' ? 'U' : 'AI';
            
            const messageContent = document.createElement('div');
            messageContent.className = 'message-content';
            messageContent.textContent = content;
            
            messageDiv.appendChild(avatar);
            messageDiv.appendChild(messageContent);
            
            chatMessages.appendChild(messageDiv);
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }
        
        // Show/hide typing indicator
        function setTyping(typing) {
            isTyping = typing;
            typingIndicator.style.display = typing ? 'block' : 'none';
            if (typing) {
                chatMessages.scrollTop = chatMessages.scrollHeight;
            }
        }
        
        // Send message
        async function sendMessage() {
            const message = messageInput.value.trim();
            if (!message || isTyping) return;
            
            // Add user message
            addMessage(message, 'user');
            messageInput.value = '';
            
            // Add to history
            conversationHistory.push({ role: 'user', content: message });
            
            // Show typing indicator
            setTyping(true);
            sendButton.disabled = true;
            
            try {
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        message: message,
                        history: conversationHistory.slice(0, -1), // Exclude current message
                        system_prompt: "You are a helpful AI assistant powered by the AIM Engine."
                    })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    addMessage(data.message, 'assistant');
                    conversationHistory = data.history;
                } else {
                    addMessage(`Error: ${data.error}`, 'assistant');
                }
            } catch (error) {
                addMessage(`Connection error: ${error.message}`, 'assistant');
            } finally {
                setTyping(false);
                sendButton.disabled = false;
                messageInput.focus();
            }
        }
        
        // Event listeners
        sendButton.addEventListener('click', sendMessage);
        
        messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
        
        clearButton.addEventListener('click', async () => {
            try {
                await fetch('/api/clear', { method: 'POST' });
                conversationHistory = [];
                chatMessages.innerHTML = `
                    <div class="message assistant">
                        <div class="avatar">AI</div>
                        <div class="message-content">
                            Hello! I'm your AI assistant powered by the AIM Engine. How can I help you today?
                        </div>
                    </div>
                `;
            } catch (error) {
                console.error('Error clearing history:', error);
            }
        });
        
        // Initial status check
        checkStatus();
        
        // Check status every 30 seconds
        setInterval(checkStatus, 30000);
    </script>
</body>
</html>
    '''

if __name__ == '__main__':
    print("🌐 Starting Web Agent Interface...")
    print("📡 Make sure your AIM Engine endpoint is running on http://localhost:8000")
    print("🌍 Web interface will be available at http://localhost:5000")
    print()
    
    app.run(debug=True, host='0.0.0.0', port=5000) 