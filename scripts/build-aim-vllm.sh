#!/bin/bash

# AIM Engine + vLLM Combined Container Build Script
# This script builds a Docker image that includes both AIM Engine's intelligent
# recipe selection tools and the vLLM ROCm runtime for maximum efficiency.

set -e

echo "Building AIM Engine + vLLM ROCm container..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build the combined container
echo "Building Docker image..."
docker build -f docker/Dockerfile.aim-vllm -t aim-vllm:latest .

echo ""
echo "Build completed successfully!"
echo ""
echo "Usage examples:"
echo "  # Generate optimal vLLM command for a model"
echo "  docker run --rm -it \\"
echo "    --device=/dev/kfd \\"
echo "    --device=/dev/dri \\"
echo "    --group-add=video \\"
echo "    --group-add=render \\"
echo "    -v /workspace/model-cache:/workspace/model-cache \\"
echo "    aim-vllm:latest \\"
echo "    aim-generate Qwen/Qwen3-32B"
echo ""
echo "  # Start interactive shell"
echo "  docker run --rm -it \\"
echo "    --device=/dev/kfd \\"
echo "    --device=/dev/dri \\"
echo "    --group-add=video \\"
echo "    --group-add=render \\"
echo "    -v /workspace/model-cache:/workspace/model-cache \\"
echo "    -p 8000:8000 \\"
echo "    aim-vllm:latest \\"
echo "    aim-shell"
echo ""
echo "  # Run vLLM server directly"
echo "  docker run --rm -it \\"
echo "    --device=/dev/kfd \\"
echo "    --device=/dev/dri \\"
echo "    --group-add=video \\"
echo "    --group-add=render \\"
echo "    -v /workspace/model-cache:/workspace/model-cache \\"
echo "    -p 8000:8000 \\"
echo "    aim-vllm:latest \\"
echo "    aim-serve Qwen/Qwen3-32B" 