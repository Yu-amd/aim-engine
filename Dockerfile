FROM rocm/vllm:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    git-lfs \
    docker.io \
    docker-compose \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install git-lfs
RUN git lfs install

# Create AIM Engine user
RUN groupadd -r aim-engine && useradd -r -g aim-engine aim-engine

# Set up model cache directory
RUN mkdir -p /workspace/model-cache && \
    chown -R aim-engine:aim-engine /workspace/model-cache

# Create cache subdirectories
RUN mkdir -p /workspace/model-cache/{models,tokenizers,configs,datasets} && \
    chown -R aim-engine:aim-engine /workspace/model-cache

# Set environment variables for caching (default behavior)
ENV HF_HOME=/workspace/model-cache
ENV TRANSFORMERS_CACHE=/workspace/model-cache
ENV HF_DATASETS_CACHE=/workspace/model-cache
ENV VLLM_CACHE_DIR=/workspace/model-cache
ENV HF_HUB_DISABLE_TELEMETRY=1
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV AIM_CACHE_DIR=/workspace/model-cache
ENV AIM_CACHE_ENABLED=1

# Set working directory
WORKDIR /opt/aim-engine

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy AIM Engine code
COPY aim_*.py ./
COPY example_usage.py ./

# Copy configuration files
COPY models/ ./models/
COPY recipes/ ./recipes/
COPY templates/ ./templates/
COPY *.json ./

# Copy cache manager
COPY aim_cache_manager.py ./
RUN chmod +x aim_cache_manager.py

# Create entrypoint script with cache support
COPY <<EOF /opt/aim-engine/entrypoint.sh
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "\${BLUE}[INFO]\${NC} \$1"
}

print_success() {
    echo -e "\${GREEN}[SUCCESS]\${NC} \$1"
}

print_warning() {
    echo -e "\${YELLOW}[WARNING]\${NC} \$1"
}

print_error() {
    echo -e "\${RED}[ERROR]\${NC} \$1"
}

# Function to check Docker
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_warning "Docker daemon not accessible. Some features may be limited."
        return 1
    fi
    return 0
}

# Function to initialize cache
init_cache() {
    print_info "Initializing model cache..."
    
    # Ensure cache directory exists and has correct permissions
    mkdir -p /workspace/model-cache/{models,tokenizers,configs,datasets}
    chown -R aim-engine:aim-engine /workspace/model-cache
    
    # Initialize cache index if it doesn't exist
    if [[ ! -f /workspace/model-cache/cache_index.json ]]; then
        python3 aim_cache_manager.py setup --cache-dir /workspace/model-cache
    fi
    
    print_success "Cache initialized at /workspace/model-cache"
}

# Function to pre-download common models (optional)
pre_download_models() {
    if [[ "\${AIM_PRE_DOWNLOAD_MODELS:-false}" == "true" ]]; then
        print_info "Pre-downloading common models..."
        
        MODELS=(
            "Qwen/Qwen3-32B"
            "meta-llama/Llama-3-8B"
            "mistralai/Mistral-7B-Instruct-v0.2"
            "microsoft/DialoGPT-medium"
        )
        
        for model in "\${MODELS[@]}"; do
            print_info "Pre-downloading \$model"
            python3 -c "
from transformers import AutoTokenizer
import os

try:
    print(f'Downloading tokenizer for {model}')
    tokenizer = AutoTokenizer.from_pretrained('\$model', cache_dir='/workspace/model-cache')
    print(f'✅ Downloaded tokenizer for {model}')
except Exception as e:
    print(f'❌ Could not download {model}: {e}')
"
        done
        
        print_success "Model pre-download completed"
    fi
}

# Function to show cache status
show_cache_status() {
    print_info "Cache Status:"
    python3 aim_cache_manager.py stats --cache-dir /workspace/model-cache
}

# Main function
main() {
    echo "🚀 AIM Engine Unified Container with Cache"
    echo "=========================================="
    echo "Cache Directory: /workspace/model-cache"
    echo "Cache Enabled: \${AIM_CACHE_ENABLED:-1}"
    echo ""
    
    # Check Docker
    check_docker
    
    # Initialize cache
    init_cache
    
    # Pre-download models if requested
    pre_download_models
    
    # Show cache status
    show_cache_status
    
    # Switch to non-root user if running as root
    if [ "\$(id -u)" = "0" ]; then
        exec gosu aim-engine "\$@"
    else
        exec "\$@"
    fi
}

main "\$@"
EOF

RUN chmod +x /opt/aim-engine/entrypoint.sh

# Create enhanced CLI wrapper with cache support
COPY <<EOF /opt/aim-engine/aim-engine
#!/usr/bin/env python3
"""
AIM Engine - Unified CLI with Cache Support
"""

import sys
import os
import argparse
from pathlib import Path

# Add current directory to Python path
sys.path.insert(0, '/opt/aim-engine')

def main():
    parser = argparse.ArgumentParser(
        description="AIM Engine - Unified AI Model Deployment with Cache",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Launch model with automatic caching
  aim-engine launch Qwen/Qwen3-32B 4
  
  # Launch with specific cache directory
  aim-engine launch Qwen/Qwen3-32B 4 --cache-dir /custom/cache
  
  # Cache management
  aim-engine cache list
  aim-engine cache stats
  aim-engine cache add Qwen/Qwen3-32B /path/to/model
  
  # Direct vLLM serving (bypasses orchestration)
  aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Launch command (orchestrated)
    launch_parser = subparsers.add_parser("launch", help="Launch model with orchestration")
    launch_parser.add_argument("model", help="Model ID (e.g., Qwen/Qwen3-32B)")
    launch_parser.add_argument("gpus", type=int, nargs="?", help="Number of GPUs (auto-detected if not specified)")
    launch_parser.add_argument("--precision", choices=["fp16", "bf16", "fp32"], help="Precision format")
    launch_parser.add_argument("--backend", default="vllm", choices=["vllm", "sglang"], help="Serving backend")
    launch_parser.add_argument("--port", type=int, default=8000, help="Port for the API server")
    launch_parser.add_argument("--cache-dir", default="/workspace/model-cache", help="Cache directory")
    launch_parser.add_argument("--no-cache", action="store_true", help="Disable caching")
    
    # Serve command (direct vLLM)
    serve_parser = subparsers.add_parser("serve", help="Direct vLLM serving")
    serve_parser.add_argument("model", help="Model ID")
    serve_parser.add_argument("--tensor-parallel-size", type=int, default=1, help="Tensor parallel size")
    serve_parser.add_argument("--port", type=int, default=8000, help="Port for the API server")
    serve_parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    serve_parser.add_argument("--cache-dir", default="/workspace/model-cache", help="Cache directory")
    
    # Cache management commands
    cache_parser = subparsers.add_parser("cache", help="Cache management")
    cache_subparsers = cache_parser.add_subparsers(dest="cache_command", help="Cache commands")
    
    cache_list_parser = cache_subparsers.add_parser("list", help="List cached models")
    cache_stats_parser = cache_subparsers.add_parser("stats", help="Show cache statistics")
    cache_add_parser = cache_subparsers.add_parser("add", help="Add model to cache")
    cache_add_parser.add_argument("model_id", help="Model ID")
    cache_add_parser.add_argument("model_path", help="Path to model files")
    cache_remove_parser = cache_subparsers.add_parser("remove", help="Remove model from cache")
    cache_remove_parser.add_argument("model_id", help="Model ID")
    cache_cleanup_parser = cache_subparsers.add_parser("cleanup", help="Clean up old models")
    cache_cleanup_parser.add_argument("--days", type=int, default=30, help="Remove models older than N days")
    
    # List command
    list_parser = subparsers.add_parser("list", help="List running models")
    
    # Stop command
    stop_parser = subparsers.add_parser("stop", help="Stop a model")
    stop_parser.add_argument("model_id", help="Model ID to stop")
    
    # Status command
    status_parser = subparsers.add_parser("status", help="Show model status")
    status_parser.add_argument("model_id", help="Model ID")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Set cache environment variables
    cache_dir = getattr(args, 'cache_dir', '/workspace/model-cache')
    os.environ.update({
        'HF_HOME': cache_dir,
        'TRANSFORMERS_CACHE': cache_dir,
        'HF_DATASETS_CACHE': cache_dir,
        'VLLM_CACHE_DIR': cache_dir,
        'HF_HUB_DISABLE_TELEMETRY': '1',
        'PYTORCH_CUDA_ALLOC_CONF': 'max_split_size_mb:512'
    })
    
    try:
        if args.command == "launch":
            from aim_launcher import AIMEngine
            engine = AIMEngine()
            
            # Check if caching is disabled
            if getattr(args, 'no_cache', False):
                print("⚠️  Caching disabled for this launch")
            else:
                print(f"✅ Using cache directory: {cache_dir}")
            
            result = engine.launch_model(
                args.model, 
                gpu_count=getattr(args, 'gpus', None),
                precision=getattr(args, 'precision', None),
                backend=args.backend,
                port=args.port
            )
            
            if result.get("success"):
                print(f"✅ Model {args.model} launched successfully")
                print(f"🌐 API available at: http://localhost:{args.port}")
            else:
                print(f"❌ Failed to launch model: {result.get('error')}")
                sys.exit(1)
        
        elif args.command == "serve":
            # Direct vLLM serving with cache
            import subprocess
            
            cmd = [
                "python", "-m", "vllm.entrypoints.openai.api_server",
                "--model", args.model,
                "--tensor-parallel-size", str(args.tensor_parallel_size),
                "--host", args.host,
                "--port", str(args.port)
            ]
            
            print(f"🚀 Starting vLLM server for {args.model}")
            print(f"🌐 API will be available at: http://{args.host}:{args.port}")
            print(f"💾 Using cache directory: {cache_dir}")
            
            subprocess.run(cmd)
        
        elif args.command == "cache":
            from aim_cache_manager import AIMCacheCLI
            cli = AIMCacheCLI(cache_dir)
            
            if args.cache_command == "list":
                cli.list_models()
            elif args.cache_command == "stats":
                cli.cache_stats()
            elif args.cache_command == "add":
                cli.add_model(args.model_id, args.model_path)
            elif args.cache_command == "remove":
                cli.remove_model(args.model_id)
            elif args.cache_command == "cleanup":
                cli.cleanup(args.days)
            else:
                cache_parser.print_help()
        
        elif args.command == "list":
            from aim_launcher import AIMEngine
            engine = AIMEngine()
            models = engine.list_models()
            if models:
                print("📋 Running Models:")
                for model in models:
                    print(f"  🔹 {model}")
            else:
                print("📋 No models currently running")
        
        elif args.command == "stop":
            from aim_launcher import AIMEngine
            engine = AIMEngine()
            result = engine.stop_model(args.model_id)
            if result.get("success"):
                print(f"✅ Model {args.model_id} stopped successfully")
            else:
                print(f"❌ Failed to stop model: {result.get('error')}")
                sys.exit(1)
        
        elif args.command == "status":
            from aim_launcher import AIMEngine
            engine = AIMEngine()
            status = engine.get_model_status(args.model_id)
            print(f"📊 Status for {args.model_id}:")
            print(f"  Status: {status.get('status', 'Unknown')}")
            print(f"  Port: {status.get('port', 'N/A')}")
            print(f"  Container: {status.get('container_id', 'N/A')}")
    
    except ImportError as e:
        print(f"❌ Error: Could not import required modules: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

RUN chmod +x /opt/aim-engine/aim-engine

# Create a cache initialization script
COPY <<EOF /opt/aim-engine/init-cache.sh
#!/bin/bash

echo "🔧 Initializing AIM Engine Cache..."

# Create cache directories
mkdir -p /workspace/model-cache/{models,tokenizers,configs,datasets}

# Set permissions
chown -R aim-engine:aim-engine /workspace/model-cache
chmod -R 755 /workspace/model-cache

echo "✅ Cache initialization completed"
echo "📁 Cache directory: /workspace/model-cache"
echo "🔧 Use 'aim-engine cache stats' to view cache status"
EOF

RUN chmod +x /opt/aim-engine/init-cache.sh

# Set entrypoint
ENTRYPOINT ["/opt/aim-engine/entrypoint.sh"]

# Default command
CMD ["aim-engine", "--help"] 