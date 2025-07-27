#!/bin/bash

# AIM Engine Endpoint Validation Script
# Run this script to verify your AIM Engine endpoint is healthy before running examples

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Default port, can be overridden
PORT=${1:-8000}
ENDPOINT="http://localhost:$PORT"

echo "=== AIM Engine Endpoint Validation ==="
echo "Testing endpoint: $ENDPOINT"
echo ""

# Check if container is running
print_status "1. Checking container status..."
if docker ps | grep -q aim-engine; then
    print_success "Container is running"
else
    print_warning "No AIM Engine container found with name 'aim-engine'"
    print_status "Checking for any aim-vllm containers..."
    if docker ps | grep -q aim-vllm; then
        print_success "Found aim-vllm container"
    else
        print_error "No AIM Engine containers found"
        print_status "Start AIM Engine with:"
        echo "docker run --rm -d \\"
        echo "  --name aim-engine \\"
        echo "  --device=/dev/kfd \\"
        echo "  --device=/dev/dri \\"
        echo "  --group-add=video \\"
        echo "  --group-add=render \\"
        echo "  -v /workspace/model-cache:/workspace/model-cache \\"
        echo "  -p $PORT:8000 \\"
        echo "  aim-vllm:latest \\"
        echo "  aim-serve Qwen/Qwen3-32B"
        exit 1
    fi
fi

# Test health endpoint
print_status "2. Testing health endpoint..."
if curl -s "$ENDPOINT/health" >/dev/null 2>&1; then
    print_success "Health endpoint responding"
    HEALTH_RESPONSE=$(curl -s "$ENDPOINT/health")
    echo "   Response: $HEALTH_RESPONSE"
else
    print_error "Health endpoint not responding"
    print_status "Container may still be starting up..."
    print_status "Check logs with: docker logs \$(docker ps -q --filter ancestor=aim-vllm:latest)"
    exit 1
fi

# Test models endpoint
print_status "3. Testing models endpoint..."
if curl -s "$ENDPOINT/v1/models" >/dev/null 2>&1; then
    print_success "Models endpoint responding"
    echo "   Available models:"
    MODELS_RESPONSE=$(curl -s "$ENDPOINT/v1/models")
    if command -v jq >/dev/null 2>&1; then
        echo "$MODELS_RESPONSE" | jq '.data[].id' 2>/dev/null || echo "   (JSON parsing failed)"
    else
        echo "   $MODELS_RESPONSE"
    fi
else
    print_error "Models endpoint not responding"
    print_status "Model may still be loading..."
    print_status "Check logs with: docker logs \$(docker ps -q --filter ancestor=aim-vllm:latest)"
    exit 1
fi

# Test chat completion endpoint
print_status "4. Testing chat completion endpoint..."
TEST_RESPONSE=$(curl -s -X POST "$ENDPOINT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }' 2>/dev/null)

if echo "$TEST_RESPONSE" | grep -q "choices"; then
    print_success "Chat completion endpoint working"
else
    print_warning "Chat completion endpoint may have issues"
    echo "   Response: $TEST_RESPONSE"
fi

echo ""
print_success "=== Validation Complete ==="
print_success "AIM Engine endpoint is ready for examples!"
echo ""
print_status "You can now run:"
echo "   ./quick_start.sh"
echo "   python3 simple_agent.py"
echo "   python3 advanced_agent.py"
echo "   python3 web_agent.py" 