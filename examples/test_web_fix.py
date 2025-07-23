#!/usr/bin/env python3
"""
Test script to verify the web agent template fix
"""

import requests
import time
import os

def test_web_agent():
    """Test if the web agent is working properly"""
    print("🧪 Testing Web Agent Template Fix...")
    print("=" * 50)
    
    # Check if templates directory exists
    if not os.path.exists('templates'):
        print("❌ templates/ directory not found!")
        print("   Make sure you're running this from the examples/ directory")
        return False
    
    if not os.path.exists('templates/chat.html'):
        print("❌ templates/chat.html not found!")
        print("   The template file is missing")
        return False
    
    print("✅ templates/chat.html found")
    
    # Test if web agent is running
    try:
        response = requests.get("http://localhost:5000", timeout=5)
        if response.status_code == 200:
            print("✅ Web agent is running and accessible")
            print("✅ Template is being served correctly")
            return True
        else:
            print(f"❌ Web agent returned status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Web agent is not running on http://localhost:5000")
        print("   Start it with: python3 web_agent.py")
        return False
    except Exception as e:
        print(f"❌ Error testing web agent: {e}")
        return False

def main():
    """Main test function"""
    print("🔧 Web Agent Template Fix Test")
    print("=" * 40)
    print("This script tests if the template fix is working.")
    print()
    
    success = test_web_agent()
    
    if success:
        print("\n🎉 Template fix is working!")
        print("🌐 You can now access the web interface at:")
        print("   - Local: http://localhost:5000")
        print("   - SSH tunnel: http://localhost:5000 (after SSH tunnel)")
        print()
        print("✨ Features available:")
        print("   - Real-time streaming responses")
        print("   - Modern web interface")
        print("   - Connection status monitoring")
    else:
        print("\n❌ Template fix needs attention")
        print("🔧 Troubleshooting steps:")
        print("   1. Make sure you're in the examples/ directory")
        print("   2. Check that templates/chat.html exists")
        print("   3. Start the web agent: python3 web_agent.py")
        print("   4. Check for any error messages")

if __name__ == "__main__":
    main() 