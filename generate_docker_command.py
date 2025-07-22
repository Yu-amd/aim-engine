#!/usr/bin/env python3
"""
Generate Docker Command - Uses AIM Engine to generate optimal Docker run commands
"""

import sys
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

from aim_recipe_selector import AIMRecipeSelector
from aim_config_generator import AIMConfigGenerator

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_docker_command.py <model_id> [gpu_count] [precision] [port]")
        print("Examples:")
        print("  python3 generate_docker_command.py Qwen/Qwen3-32B")
        print("  python3 generate_docker_command.py Qwen/Qwen3-32B 4")
        print("  python3 generate_docker_command.py Qwen/Qwen3-32B 4 bf16")
        print("  python3 generate_docker_command.py Qwen/Qwen3-32B 4 bf16 8001")
        sys.exit(1)
    
    model_id = sys.argv[1]
    gpu_count = int(sys.argv[2]) if len(sys.argv) > 2 else None
    precision = sys.argv[3] if len(sys.argv) > 3 else None
    port = int(sys.argv[4]) if len(sys.argv) > 4 else 8000
    
    try:
        # Get optimal configuration using AIM Engine
        selector = AIMRecipeSelector(Path("."))
        config = selector.get_optimal_configuration(model_id, gpu_count, precision)
        
        if not config:
            print(f"No configuration found for {model_id}")
            sys.exit(1)
        
        # Get recipe and generate vLLM command
        recipe = selector.get_recipe_info(config["recipe_id"])
        generator = AIMConfigGenerator()
        deployment_config = generator.generate_config(
            recipe, config['gpu_count'], config['precision'], config['backend'], 8000  # vLLM always runs on 8000 inside container
        )
        
        vllm_command = deployment_config.get("command", "")
        
        # Generate container name
        model_safe = model_id.replace("/", "-").lower()
        container_name = f"vllm-{model_safe}-{config['gpu_count']}gpu-{config['precision']}"
        
        # Build the Docker command
        docker_command = f"""docker run --rm \\
  --name {container_name} \\
  --device=/dev/kfd \\
  --device=/dev/dri \\
  --group-add=video \\
  --group-add=render \\
  -v /workspace/model-cache:/workspace/model-cache \\
  -p {port}:8000 \\
  rocm/vllm:latest \\
  {vllm_command}"""
        
        # Output the command
        print(f"# AIM Engine Recipe: {config['recipe_id']}")
        print(f"# Model: {model_id}")
        print(f"# GPUs: {config['gpu_count']} (from {config['available_gpus']} available)")
        print(f"# Precision: {config['precision']}")
        print(f"# Backend: {config['backend']}")
        print(f"# Port: {port}")
        print()
        print(docker_command)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 