#!/usr/bin/env python3
"""
Web Agent Access Diagnostic Tool
Helps diagnose network connectivity issues for the web agent.
"""

import socket
import requests
import subprocess
import os
from flask import Flask

def check_local_network():
    """Check local network configuration"""
    print("🔍 Network Configuration Check")
    print("=" * 40)
    
    # Get local IP addresses
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        print(f"Hostname: {hostname}")
        print(f"Local IP: {local_ip}")
    except Exception as e:
        print(f"Error getting network info: {e}")
    
    # Check all network interfaces
    try:
        result = subprocess.run(['ip', 'addr', 'show'], capture_output=True, text=True)
        if result.returncode == 0:
            print("\nNetwork Interfaces:")
            for line in result.stdout.split('\n'):
                if 'inet ' in line and '127.0.0.1' not in line:
                    print(f"  {line.strip()}")
    except Exception as e:
        print(f"Error checking network interfaces: {e}")

def check_port_accessibility(port=5000):
    """Check if port is accessible"""
    print(f"\n🔌 Port {port} Accessibility Check")
    print("=" * 40)
    
    # Check if port is listening
    try:
        result = subprocess.run(['netstat', '-tlnp'], capture_output=True, text=True)
        if result.returncode == 0:
            if f':{port} ' in result.stdout:
                print(f"✅ Port {port} is listening")
                for line in result.stdout.split('\n'):
                    if f':{port} ' in line:
                        print(f"  {line.strip()}")
            else:
                print(f"❌ Port {port} is not listening")
        else:
            print("❌ Could not check port status")
    except Exception as e:
        print(f"Error checking port: {e}")
    
    # Check if port is accessible locally
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        result = sock.connect_ex(('localhost', port))
        sock.close()
        if result == 0:
            print(f"✅ Port {port} is accessible locally")
        else:
            print(f"❌ Port {port} is not accessible locally")
    except Exception as e:
        print(f"Error checking local port access: {e}")

def check_firewall():
    """Check firewall status"""
    print("\n🔥 Firewall Check")
    print("=" * 40)
    
    # Check UFW status
    try:
        result = subprocess.run(['ufw', 'status'], capture_output=True, text=True)
        if result.returncode == 0:
            print("UFW Status:")
            print(result.stdout)
        else:
            print("UFW not installed or not running")
    except Exception as e:
        print(f"Error checking UFW: {e}")
    
    # Check iptables
    try:
        result = subprocess.run(['iptables', '-L'], capture_output=True, text=True)
        if result.returncode == 0:
            print("\nIptables rules (first 10 lines):")
            lines = result.stdout.split('\n')[:10]
            for line in lines:
                print(f"  {line}")
    except Exception as e:
        print(f"Error checking iptables: {e}")

def test_web_agent():
    """Test web agent connectivity"""
    print("\n🌐 Web Agent Connectivity Test")
    print("=" * 40)
    
    # Test local connection
    try:
        response = requests.get('http://localhost:5000', timeout=5)
        if response.status_code == 200:
            print("✅ Web agent is accessible locally")
        else:
            print(f"❌ Web agent returned status code: {response.status_code}")
    except requests.exceptions.ConnectionError:
        print("❌ Web agent is not accessible locally")
    except Exception as e:
        print(f"Error testing web agent: {e}")
    
    # Test AIM Engine endpoint
    try:
        response = requests.get('http://localhost:8000/v1/models', timeout=5)
        if response.status_code == 200:
            print("✅ AIM Engine endpoint is accessible")
        else:
            print(f"❌ AIM Engine endpoint returned status code: {response.status_code}")
    except requests.exceptions.ConnectionError:
        print("❌ AIM Engine endpoint is not accessible")
    except Exception as e:
        print(f"Error testing AIM Engine: {e}")

def main():
    """Run all diagnostic checks"""
    print("🚀 Web Agent Access Diagnostic Tool")
    print("=" * 50)
    print()
    
    check_local_network()
    check_port_accessibility()
    check_firewall()
    test_web_agent()
    
    print("\n📋 Access Instructions:")
    print("=" * 40)
    print("1. If on same network: http://<remote-ip>:5000")
    print("2. If using SSH: ssh -L 5000:localhost:5000 user@remote-host")
    print("   Then access: http://localhost:5000")
    print("3. If behind firewall: Use reverse SSH tunnel")
    print()
    print("🔧 Troubleshooting:")
    print("- Check if port 5000 is open in firewall")
    print("- Ensure web agent is running with host='0.0.0.0'")
    print("- Verify AIM Engine is running on port 8000")

if __name__ == "__main__":
    main() 