#!/usr/bin/env python3
"""
AIM Engine Command Generator
Generates optimal vLLM commands based on model and hardware.
"""

import sys
import subprocess
import os
from pathlib import Path
from aim_recipe_selector import AIMRecipeSelector

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 aim_generate_command.py <model_id> [--serve]")
        print("Example: python3 aim_generate_command.py Qwen/Qwen3-32B")
        print("Example: python3 aim_generate_command.py Qwen/Qwen3-32B --serve")
        sys.exit(1)
    
    model_id = sys.argv[1]
    serve_mode = "--serve" in sys.argv
    
    try:
        # Initialize selector
        selector = AIMRecipeSelector(Path("."))
        
        # Select recipe
        recipe = selector.select_recipe(model_id, 2, "bf16", "vllm")
        
        if recipe:
            # Get the specific configuration for 2 GPUs
            config = selector.get_recipe_config(recipe, 2, "vllm")
            
            if config and 'args' in config:
                # Convert args dictionary to string
                args_list = []
                for key, value in config['args'].items():
                    if key.startswith('--'):
                        args_list.append(f"{key} {value}")
                    else:
                        args_list.append(f"--{key} {value}")
                
                vllm_args = " ".join(args_list)
                
                if serve_mode:
                    # Direct execution mode - run vLLM server directly
                    print(f"Starting vLLM server for model: {model_id}")
                    print(f"Arguments: {vllm_args}")
                    
                    # Split the arguments for subprocess
                    cmd = ["python3", "-m", "vllm.entrypoints.openai.api_server"] + vllm_args.split()
                    
                    # Execute vLLM server directly
                    os.execvp("python3", ["python3", "-m", "vllm.entrypoints.openai.api_server"] + vllm_args.split())
                else:
                    # Generate mode - print the docker command
                    docker_cmd = f"""docker run --rm -d \\
  --device=/dev/kfd \\
  --device=/dev/dri \\
  --group-add=video \\
  --group-add=render \\
  -v /workspace/model-cache:/workspace/model-cache \\
  -p 8000:8000 \\
  rocm/vllm:latest \\
  python3 -m vllm.entrypoints.openai.api_server \\
  {vllm_args}"""
                    
                    print(docker_cmd)
            else:
                print(f"No valid configuration found for model: {model_id}")
                sys.exit(1)
        else:
            print(f"No recipe found for model: {model_id}")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 