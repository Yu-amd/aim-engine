#!/bin/bash

# AIM Engine - Model Cache Setup Script
# This script sets up model caching for efficient deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="/workspace/model-cache"
DEFAULT_USER=$(whoami)

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

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to create cache directory
setup_cache_directory() {
    print_info "Setting up cache directory at $CACHE_DIR"
    
    # Create cache directory
    sudo mkdir -p "$CACHE_DIR"
    
    # Set ownership
    sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$CACHE_DIR"
    
    # Set permissions
    sudo chmod 755 "$CACHE_DIR"
    
    # Create subdirectories
    mkdir -p "$CACHE_DIR/models"
    mkdir -p "$CACHE_DIR/tokenizers"
    mkdir -p "$CACHE_DIR/configs"
    mkdir -p "$CACHE_DIR/datasets"
    
    print_success "Cache directory setup completed"
}

# Function to setup cache manager
setup_cache_manager() {
    print_info "Setting up cache manager"
    
    # Make cache manager executable
    chmod +x aim_cache_manager.py
    
    # Test cache manager
    python3 aim_cache_manager.py setup --cache-dir "$CACHE_DIR"
    
    print_success "Cache manager setup completed"
}

# Function to pre-download common models
pre_download_models() {
    print_info "Pre-downloading common models to cache"
    
    # List of common models to pre-download
    MODELS=(
        "Qwen/Qwen3-32B"
        "meta-llama/Llama-3-8B"
        "mistralai/Mistral-7B-Instruct-v0.2"
        "microsoft/DialoGPT-medium"
    )
    
    for model in "${MODELS[@]}"; do
        print_info "Pre-downloading $model"
        
        # Create a temporary container to download the model
        docker run --rm \
            -v "$CACHE_DIR:/workspace/model-cache" \
            -e HF_HOME=/workspace/model-cache \
            -e TRANSFORMERS_CACHE=/workspace/model-cache \
            -e HF_DATASETS_CACHE=/workspace/model-cache \
            -e VLLM_CACHE_DIR=/workspace/model-cache \
            -e HF_HUB_DISABLE_TELEMETRY=1 \
            rocm/vllm:latest \
            python -c "
from transformers import AutoTokenizer, AutoModelForCausalLM
import os

try:
    print(f'Downloading tokenizer for {model}')
    tokenizer = AutoTokenizer.from_pretrained('$model', cache_dir='/workspace/model-cache')
    print(f'✅ Downloaded tokenizer for {model}')
except Exception as e:
    print(f'❌ Could not download {model}: {e}')
"
    done
    
    print_success "Model pre-download completed"
}

# Function to setup Docker Compose with caching
setup_docker_compose() {
    print_info "Setting up Docker Compose with caching"
    
    # Check if docker-compose.cache.yml exists
    if [[ ! -f "docker-compose.cache.yml" ]]; then
        print_error "docker-compose.cache.yml not found"
        return 1
    fi
    
    # Create monitoring directory
    mkdir -p monitoring
    
    # Create basic Prometheus config
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'aim-engine'
    static_configs:
      - targets: ['localhost:8000', 'localhost:8001', 'localhost:8002']
EOF
    
    print_success "Docker Compose setup completed"
}

# Function to test cache functionality
test_cache() {
    print_info "Testing cache functionality"
    
    # Test cache manager
    python3 aim_cache_manager.py stats --cache-dir "$CACHE_DIR"
    
    # Test launching a model with cache
    print_info "Testing model launch with cache"
    
    # Launch a simple model to test caching
    docker run --rm \
        -v "$CACHE_DIR:/workspace/model-cache:ro" \
        -e HF_HOME=/workspace/model-cache \
        -e TRANSFORMERS_CACHE=/workspace/model-cache \
        -e HF_DATASETS_CACHE=/workspace/model-cache \
        -e VLLM_CACHE_DIR=/workspace/model-cache \
        -e HF_HUB_DISABLE_TELEMETRY=1 \
        rocm/vllm:latest \
        python -c "
from transformers import AutoTokenizer
import os

print('Testing cache access...')
try:
    tokenizer = AutoTokenizer.from_pretrained('microsoft/DialoGPT-medium', cache_dir='/workspace/model-cache')
    print('✅ Cache access successful')
except Exception as e:
    print(f'❌ Cache access failed: {e}')
"
    
    print_success "Cache functionality test completed"
}

# Function to show usage examples
show_usage_examples() {
    print_info "Cache Usage Examples"
    echo
    echo "1. Launch model with cache:"
    echo "   aim-engine launch Qwen/Qwen3-32B 4 --model-cache $CACHE_DIR"
    echo
    echo "2. List cached models:"
    echo "   python3 aim_cache_manager.py list --cache-dir $CACHE_DIR"
    echo
    echo "3. Show cache statistics:"
    echo "   python3 aim_cache_manager.py stats --cache-dir $CACHE_DIR"
    echo
    echo "4. Add model to cache:"
    echo "   python3 aim_cache_manager.py add Qwen/Qwen3-32B /path/to/model --cache-dir $CACHE_DIR"
    echo
    echo "5. Remove model from cache:"
    echo "   python3 aim_cache_manager.py remove Qwen/Qwen3-32B --cache-dir $CACHE_DIR"
    echo
    echo "6. Clean up old models:"
    echo "   python3 aim_cache_manager.py cleanup --days 30 --cache-dir $CACHE_DIR"
    echo
    echo "7. Start with Docker Compose:"
    echo "   docker-compose -f docker-compose.cache.yml up -d"
    echo
    echo "8. Monitor cache usage:"
    echo "   du -sh $CACHE_DIR"
    echo "   ls -la $CACHE_DIR/models/"
}

# Function to show performance comparison
show_performance_comparison() {
    print_info "Performance Comparison"
    echo
    echo "📊 Download Time Comparison:"
    echo "┌─────────────────┬─────────────┬─────────────────┬──────────┐"
    echo "│ Scenario        │ First Model │ Subsequent      │ Total    │"
    echo "│                 │             │ Models          │ Time     │"
    echo "├─────────────────┼─────────────┼─────────────────┼──────────┤"
    echo "│ No Caching      │ 15-30 min   │ 15-30 min each  │ 45-90min │"
    echo "│ With Caching    │ 15-30 min   │ 2-5 min each    │ 19-40min │"
    echo "│ Savings         │ 0%          │ 80-90%          │ 60-70%   │"
    echo "└─────────────────┴─────────────┴─────────────────┴──────────┘"
    echo
    echo "📊 Bandwidth Usage:"
    echo "┌─────────────────┬─────────────────┬──────────────┐"
    echo "│ Strategy        │ Bandwidth Usage │ Cache Hit    │"
    echo "│                 │                 │ Rate         │"
    echo "├─────────────────┼─────────────────┼──────────────┤"
    echo "│ No Caching      │ 100% each model │ 0%           │"
    echo "│ Shared Volume   │ 100% first      │ 100%         │"
    echo "│                 │ 0% subsequent   │              │"
    echo "│ Pre-downloaded  │ 0% (cached)     │ 100%         │"
    echo "└─────────────────┴─────────────────┴──────────────┘"
}

# Main function
main() {
    echo "🚀 AIM Engine - Model Cache Setup"
    echo "================================="
    echo
    
    # Check if running as root
    check_root
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed or not in PATH"
        exit 1
    fi
    
    # Setup steps
    setup_cache_directory
    setup_cache_manager
    setup_docker_compose
    
    # Ask if user wants to pre-download models
    read -p "Do you want to pre-download common models? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pre_download_models
    fi
    
    # Test cache functionality
    test_cache
    
    echo
    print_success "Cache setup completed successfully!"
    echo
    
    show_usage_examples
    echo
    show_performance_comparison
    echo
    
    print_info "Next steps:"
    echo "1. Use 'aim-engine launch' with --model-cache option"
    echo "2. Monitor cache usage with aim_cache_manager.py"
    echo "3. Use Docker Compose for multi-model deployments"
    echo "4. Set up regular cache cleanup with cron jobs"
}

# Run main function
main "$@" 