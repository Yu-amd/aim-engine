#!/bin/bash

# Test script to verify the sudo Docker fix works
# This simulates the Docker permission issue and tests the fix

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "🧪 Testing sudo Docker fix..."

# Test 1: Check if Docker is working
log_info "Test 1: Checking Docker status..."
if docker ps > /dev/null 2>&1; then
    log_success "Docker is working directly!"
    docker --version
    docker ps
else
    log_warning "Docker not accessible directly, testing sudo..."
    
    # Test sudo docker
    if sudo docker ps > /dev/null 2>&1; then
        log_success "Docker works with sudo!"
        
        # Test the function creation
        log_info "Testing function creation..."
        eval 'docker() { sudo docker "$@"; }'
        
        # Test the function
        if docker ps > /dev/null 2>&1; then
            log_success "Docker function created and working!"
            docker --version
            docker ps
        else
            log_error "Docker function failed"
            exit 1
        fi
    else
        log_error "Docker not accessible even with sudo"
        exit 1
    fi
fi

# Test 2: Test registry creation
log_info "Test 2: Testing registry creation..."
if docker run -d --name test-registry -p 5000:5000 --rm registry:2 2>/dev/null; then
    log_success "Registry container created successfully!"
    
    # Wait for registry
    sleep 5
    
    # Test registry
    if curl -s http://localhost:5000/v2/_catalog > /dev/null 2>&1; then
        log_success "Registry is responding!"
    else
        log_warning "Registry not responding yet"
    fi
    
    # Cleanup
    docker stop test-registry 2>/dev/null || true
    docker rm test-registry 2>/dev/null || true
else
    log_error "Failed to create registry container"
    exit 1
fi

log_success "🎉 Sudo Docker fix test completed successfully!"
log_info "The fix should now work in the main setup script." 