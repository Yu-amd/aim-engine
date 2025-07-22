#!/usr/bin/env python3
"""
Simple script to get vLLM command using AIM Engine recipe selection
"""

import sys
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

from aim_recipe_selector import AIMRecipeSelector
from aim_config_generator import AIMConfigGenerator

def main():
    if len(sys.argv) < 2:
        print("Usage: python get_vllm_command.py <model_id>")
        print("Example: python get_vllm_command.py Qwen/Qwen3-32B")
        sys.exit(1)
    
    model_id = sys.argv[1]
    
    try:
        # Get optimal configuration
        selector = AIMRecipeSelector(Path("."))
        config = selector.get_optimal_configuration(model_id)
        
        if not config:
            print(f"No configuration found for {model_id}")
            sys.exit(1)
        
        # Get recipe and generate vLLM command
        recipe = selector.get_recipe_info(config["recipe_id"])
        generator = AIMConfigGenerator()
        deployment_config = generator.generate_config(
            recipe, config['gpu_count'], config['precision'], config['backend'], 8000
        )
        
        vllm_command = deployment_config.get("command", "")
        
        print(f"# AIM Engine Recipe: {config['recipe_id']}")
        print(f"# Model: {model_id}")
        print(f"# GPUs: {config['gpu_count']} (from {config['available_gpus']} available)")
        print(f"# Precision: {config['precision']}")
        print(f"# Backend: {config['backend']}")
        print()
        print(f"docker run --rm \\")
        print(f"  --device=/dev/kfd \\")
        print(f"  --device=/dev/dri \\")
        print(f"  --group-add=video \\")
        print(f"  --group-add=render \\")
        print(f"  -v /workspace/model-cache:/workspace/model-cache \\")
        print(f"  -p 8000:8000 \\")
        print(f"  rocm/vllm:latest \\")
        print(f"  {vllm_command}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 