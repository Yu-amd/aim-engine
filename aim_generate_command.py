#!/usr/bin/env python3
"""
AIM Engine Command Generator
Generates optimal vLLM commands based on model and hardware.
"""

import sys
from pathlib import Path
from aim_recipe_selector import AIMRecipeSelector

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 aim_generate_command.py <model_id>")
        print("Example: python3 aim_generate_command.py Qwen/Qwen3-32B")
        sys.exit(1)
    
    model_id = sys.argv[1]
    
    try:
        # Initialize selector
        selector = AIMRecipeSelector(Path("."))
        
        # Select recipe
        recipe = selector.select_recipe(model_id, 2, "bf16", "vllm")
        
        if recipe:
            # Generate the docker command
            docker_cmd = f"""docker run --rm -d \\
  --device=/dev/kfd \\
  --device=/dev/dri \\
  --group-add=video \\
  --group-add=render \\
  -v /workspace/model-cache:/workspace/model-cache \\
  -p 8000:8000 \\
  rocm/vllm:latest \\
  python3 -m vllm.entrypoints.openai.api_server \\
  --model {recipe['model_id']} \\
  --port 8000 \\
  {recipe['vllm_args']}"""
            
            print(docker_cmd)
        else:
            print(f"No recipe found for model: {model_id}")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 