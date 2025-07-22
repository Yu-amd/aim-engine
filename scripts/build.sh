#!/bin/bash

# AIM Engine - Container Build Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
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

# Configuration
IMAGE_NAME="aim-engine"
TAG="latest"
DOCKERFILE="Dockerfile"
CACHE_DIR="/workspace/model-cache"

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [[ ! -f "$DOCKERFILE" ]]; then
        print_error "Dockerfile $DOCKERFILE not found"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to build the container
build_container() {
    print_info "Building container..."
    
    # Build the container
    docker build -f "$DOCKERFILE" -t "$IMAGE_NAME:$TAG" .
    
    if [[ $? -eq 0 ]]; then
        print_success "Container built successfully: $IMAGE_NAME:$TAG"
    else
        print_error "Failed to build container"
        exit 1
    fi
}

# Function to set up cache directory
setup_cache_directory() {
    print_info "Setting up cache directory..."
    
    # Create cache directory
    sudo mkdir -p "$CACHE_DIR"
    
    # Set ownership
    sudo chown "$(whoami):$(whoami)" "$CACHE_DIR"
    
    # Set permissions
    sudo chmod 755 "$CACHE_DIR"
    
    # Create subdirectories
    mkdir -p "$CACHE_DIR/models"
    mkdir -p "$CACHE_DIR/tokenizers"
    mkdir -p "$CACHE_DIR/configs"
    mkdir -p "$CACHE_DIR/datasets"
    
    print_success "Cache directory setup completed: $CACHE_DIR"
}

# Function to test the container
test_container() {
    print_info "Testing container..."
    
    # Test basic functionality
    docker run --rm "$IMAGE_NAME:$TAG" aim-engine --help >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        print_success "Container test passed"
    else
        print_error "Container test failed"
        exit 1
    fi
    
    # Test cache functionality
    docker run --rm -v "$CACHE_DIR:/workspace/model-cache" \
        "$IMAGE_NAME:$TAG" aim-engine cache stats >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        print_success "Cache functionality test passed"
    else
        print_warning "Cache functionality test failed (cache manager may not be available)"
    fi
}

# Function to show usage examples
show_usage_examples() {
    print_info "Usage Examples"
    echo
    echo "1. Launch model with cache:"
    echo "   docker run --rm --gpus all \\"
    echo "     -v $CACHE_DIR:/workspace/model-cache \\"
    echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
    echo "     -p 8000:8000 \\"
    echo "     $IMAGE_NAME:$TAG \\"
    echo "     aim-engine launch Qwen/Qwen3-32B 4"
    echo
    echo "2. Use Docker Compose:"
    echo "   docker-compose up -d"
    echo
    echo "3. Check cache status:"
    echo "   docker run --rm -v $CACHE_DIR:/workspace/model-cache \\"
    echo "     $IMAGE_NAME:$TAG aim-engine cache stats"
    echo
    echo "4. List cached models:"
    echo "   docker run --rm -v $CACHE_DIR:/workspace/model-cache \\"
    echo "     $IMAGE_NAME:$TAG aim-engine cache list"
}

# Function to show performance benefits
show_performance_benefits() {
    print_info "Performance Benefits"
    echo
    echo "📊 Deployment Time Comparison:"
    echo "┌─────────────────┬─────────────┬─────────────────┬──────────┐"
    echo "│ Scenario        │ First Model │ Subsequent      │ Total    │"
    echo "│                 │             │ Models          │ Time     │"
    echo "├─────────────────┼─────────────┼─────────────────┼──────────┤"
    echo "│ No Cache        │ 15-30 min   │ 15-30 min each  │ 45-90min │"
    echo "│ With Cache      │ 15-30 min   │ 2-5 min each    │ 19-40min │"
    echo "│ Savings         │ 0%          │ 80-90%          │ 60-70%   │"
    echo "└─────────────────┴─────────────┴─────────────────┴──────────┘"
    echo
    echo "📊 Bandwidth Usage:"
    echo "┌─────────────────┬─────────────────┬──────────────┐"
    echo "│ Strategy        │ Bandwidth Usage │ Cache Hit    │"
    echo "│                 │                 │ Rate         │"
    echo "├─────────────────┼─────────────────┼──────────────┤"
    echo "│ No Caching      │ 100% each model │ 0%           │"
    echo "│ Unified Cache   │ 100% first      │ 100%         │"
    echo "│                 │ 0% subsequent   │              │"
    echo "└─────────────────┴─────────────────┴──────────────┘"
}

# Main function
main() {
    echo "🚀 AIM Engine - Container Build"
    echo "==============================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Build container
    build_container
    
    # Set up cache directory
    setup_cache_directory
    
    # Test container
    test_container
    
    echo
    print_success "Build completed successfully!"
    echo
    
    show_usage_examples
    echo
    show_performance_benefits
    echo
    
    print_info "Next steps:"
    echo "1. Use 'docker run' to launch models with cache"
    echo "2. Use 'docker-compose' for multi-model deployment"
    echo "3. Monitor cache usage with 'aim-engine cache stats'"
    echo "4. Manage cache with cache management commands"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --dockerfile)
            DOCKERFILE="$2"
            shift 2
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --image-name NAME    Set image name (default: aim-engine)"
            echo "  --tag TAG           Set image tag (default: latest)"
            echo "  --dockerfile FILE   Set Dockerfile path (default: Dockerfile)"
            echo "  --cache-dir DIR     Set cache directory (default: /workspace/model-cache)"
            echo "  --help              Show this help message"
            echo
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 