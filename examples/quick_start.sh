#!/bin/bash

# AIM Engine Agent Examples - Quick Start Script

set -e

echo "🚀 AIM Engine Agent Examples - Quick Start"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "../build-aim-vllm.sh" ]; then
    print_error "Please run this script from the examples/ directory"
    exit 1
fi

# Check if Docker is running
print_status "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi
print_success "Docker is running"

# Check if AIM Engine container exists
print_status "Checking AIM Engine container..."
if ! docker images | grep -q "aim-vllm"; then
    print_warning "AIM Engine container not found. Building..."
    cd ..
    ./build-aim-vllm.sh
    cd examples
else
    print_success "AIM Engine container found"
fi

# Check if Python dependencies are installed
print_status "Checking Python dependencies..."
if ! python3 -c "import requests, flask" 2>/dev/null; then
    print_warning "Installing Python dependencies..."
    pip install -r requirements.txt
else
    print_success "Python dependencies are installed"
fi

# Function to check if port is available
check_port() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# Check if port 8000 is available
if check_port 8000; then
    print_warning "Port 8000 is already in use. Checking if it's AIM Engine..."
    if curl -s http://localhost:8000/v1/models >/dev/null 2>&1; then
        print_success "AIM Engine is already running on port 8000"
        AIM_ENGINE_RUNNING=true
    else
        print_error "Port 8000 is in use by another service. Please free it up."
        exit 1
    fi
else
    AIM_ENGINE_RUNNING=false
fi

# Start AIM Engine if not running
if [ "$AIM_ENGINE_RUNNING" = false ]; then
    print_status "Starting AIM Engine..."
    
    # Start the container in the background
    CONTAINER_ID=$(docker run -d \
        --device=/dev/kfd \
        --device=/dev/dri \
        --group-add=video \
        --group-add=render \
        -v /workspace/model-cache:/workspace/model-cache \
        -p 8000:8000 \
        aim-vllm:latest \
        aim-serve Qwen/Qwen3-32B)
    
    print_success "AIM Engine container started (ID: $CONTAINER_ID)"
    
    # Wait for the service to be ready
    print_status "Waiting for AIM Engine to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8000/v1/models >/dev/null 2>&1; then
            print_success "AIM Engine is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "AIM Engine failed to start within 30 seconds"
            print_status "Container logs:"
            docker logs $CONTAINER_ID
            exit 1
        fi
        sleep 1
    done
fi

# Function to show menu
show_menu() {
    echo ""
    echo "🤖 Choose an agent example to run:"
    echo "1. Simple Agent (Command Line)"
    echo "2. Advanced Agent (Command Line with Tools)"
    echo "3. Web Agent (Browser Interface)"
    echo "4. Check AIM Engine Status"
    echo "5. Stop AIM Engine"
    echo "6. Exit"
    echo ""
    read -p "Enter your choice (1-6): " choice
}

# Function to run simple agent
run_simple_agent() {
    print_status "Starting Simple Agent..."
    python3 simple_agent.py
}

# Function to run advanced agent
run_advanced_agent() {
    print_status "Starting Advanced Agent..."
    python3 advanced_agent.py
}

# Function to run web agent
run_web_agent() {
    print_status "Starting Web Agent..."
    print_success "Web interface will be available at http://localhost:5000"
    print_status "Press Ctrl+C to stop the web server"
    python3 web_agent.py
}

# Function to check status
check_status() {
    print_status "Checking AIM Engine status..."
    if curl -s http://localhost:8000/v1/models >/dev/null 2>&1; then
        print_success "AIM Engine is running and responding"
        print_status "Available models:"
        curl -s http://localhost:8000/v1/models | python3 -m json.tool
    else
        print_error "AIM Engine is not responding"
    fi
}

# Function to stop AIM Engine
stop_aim_engine() {
    print_status "Stopping AIM Engine..."
    CONTAINER_ID=$(docker ps -q --filter "ancestor=aim-vllm:latest")
    if [ -n "$CONTAINER_ID" ]; then
        docker stop $CONTAINER_ID
        print_success "AIM Engine stopped"
    else
        print_warning "No AIM Engine container found"
    fi
}

# Main menu loop
while true; do
    show_menu
    
    case $choice in
        1)
            run_simple_agent
            ;;
        2)
            run_advanced_agent
            ;;
        3)
            run_web_agent
            ;;
        4)
            check_status
            ;;
        5)
            stop_aim_engine
            ;;
        6)
            print_success "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1-6."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done 