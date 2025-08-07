#!/bin/bash

# Test script to verify Docker fix works
# Run this before the full setup to ensure Docker is working

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

log_info "🧪 Testing Docker fix..."

# Test 1: Check if Docker is working
log_info "Test 1: Checking Docker status..."
if docker ps > /dev/null 2>&1; then
    log_success "Docker is working!"
    docker --version
    docker ps
else
    log_error "Docker is not working"
    log_info "Running Docker fix from setup script..."
    
    # Run just the Docker setup part
    source k8s/scripts/setup-complete-kubernetes.sh
    
    # The script will exit if Docker setup fails
    log_success "Docker fix completed successfully!"
fi

# Test 2: Test registry
log_info "Test 2: Testing local registry..."
if curl -s http://localhost:5000/v2/_catalog > /dev/null 2>&1; then
    log_success "Local registry is working!"
else
    log_warning "Local registry not responding, but Docker is working"
    log_info "Registry will be set up during full installation"
fi

log_success "🎉 Docker test completed! Ready to run full setup." 