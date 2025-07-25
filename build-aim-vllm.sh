#!/bin/bash

# Build AIM Engine + vLLM Combined Container
set -e

echo "🚀 Building AIM Engine + vLLM ROCm Container..."

# Build the combined container
docker build -f Dockerfile.aim-vllm -t aim-vllm:latest .

echo "✅ Build completed successfully!"
echo ""
echo "📋 Usage Examples:"
echo ""
echo "1. Generate optimal vLLM command:"
echo "   docker run --rm -it \\"
echo "     --device=/dev/kfd \\"
echo "     --device=/dev/dri \\"
echo "     --group-add=video \\"
echo "     --group-add=render \\"
echo "     -v /workspace/model-cache:/workspace/model-cache \\"
echo "     aim-vllm:latest \\"
echo "     aim-generate Qwen/Qwen3-32B"
echo ""
echo "2. Run vLLM server (interactive mode - recommended):"
echo "   docker run --rm -it \\"
echo "     --device=/dev/kfd \\"
echo "     --device=/dev/dri \\"
echo "     --group-add=video \\"
echo "     --group-add=render \\"
echo "     -v /workspace/model-cache:/workspace/model-cache \\"
echo "     -p 8000:8000 \\"
echo "     aim-vllm:latest \\"
echo "     aim-shell"
echo ""
echo "3. Interactive shell:"
echo "   docker run --rm -it \\"
echo "     --device=/dev/kfd \\"
echo "     --device=/dev/dri \\"
echo "     --group-add=video \\"
echo "     --group-add=render \\"
echo "     -v /workspace/model-cache:/workspace/model-cache \\"
echo "     aim-vllm:latest \\"
echo "     aim-shell"
echo ""
echo "4. Run custom Python commands:"
echo "   docker run --rm -it \\"
echo "     --device=/dev/kfd \\"
echo "     --device=/dev/dri \\"
echo "     --group-add=video \\"
echo "     --group-add=render \\"
echo "     -v /workspace/model-cache:/workspace/model-cache \\"
echo "     aim-vllm:latest \\"
echo "     python3 -c \"from aim_recipe_selector import AIMRecipeSelector; print('AIM Engine loaded!')\"" 