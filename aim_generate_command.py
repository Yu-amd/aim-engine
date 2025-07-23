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

def detect_available_gpus():
    """Detect the actual number of GPUs available in the container"""
    try:
        # Try PyTorch detection first
        import torch
        if torch.cuda.is_available():
            gpu_count = torch.cuda.device_count()
            if gpu_count > 0:
                return gpu_count
    except:
        pass
    
    try:
        # Try rocm-smi
        result = subprocess.run(['rocm-smi', '--showproductname'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            # Count lines that contain GPU info
            lines = result.stdout.strip().split('\n')
            gpu_count = len([line for line in lines if 'GPU' in line or 'MI' in line])
            if gpu_count > 0:
                return gpu_count
    except:
        pass
    
    # Fallback to 1 GPU
    return 1

def convert_args_to_command_line(args_dict):
    """Convert args dictionary to proper command line arguments"""
    args_list = []
    
    # Define boolean flags that should not have values
    boolean_flags = {
        '--trust-remote-code',
        '--enforce-eager',
        '--disable-sliding-window',
        '--disable-cascade-attn',
        '--skip-tokenizer-init',
        '--enable-prompt-embeds',
        '--disable-async-output-proc',
        '--enable-sleep-mode',
        '--enable-lora',
        '--enable-lora-bias',
        '--fully-sharded-loras',
        '--enable-prompt-adapter',
        '--enable-reasoning',
        '--enable-prefix-caching',
        '--calculate-kv-scales',
        '--disable-mm-preprocessor-cache',
        '--enable-chunked-prefill',
        '--disable-chunked-mm-input',
        '--disable-hybrid-kv-cache-manager',
        '--use-v2-block-manager',
        '--disable-log-stats',
        '--disable-log-requests',
        '--disable-fastapi-docs',
        '--enable-prompt-tokens-details',
        '--enable-force-include-usage',
        '--enable-server-load-tracking',
        '--multi-step-stream-outputs',
        '--eplb-log-balancedness',
        '--ray-workers-use-nsight',
        '--disable-custom-all-reduce',
        '--enable-multimodal-encoder-data-parallel'
    }
    
    for key, value in args_dict.items():
        if key.startswith('--'):
            flag = key
        else:
            flag = f"--{key}"
        
        # Check if this is a boolean flag
        if flag in boolean_flags:
            # For boolean flags, only add the flag if value is True, 'true', 'True', '1', 'yes', 'Yes'
            value_str = str(value).strip().lower()
            if value_str in ['true', '1', 'yes']:
                args_list.append(flag)
            # Skip boolean flags with false values
        else:
            # For non-boolean flags, add flag and value
            args_list.append(f"{flag} {value}")
    
    return " ".join(args_list)

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
        
        # Detect actual available GPUs in container
        available_gpus = detect_available_gpus()
        print(f"Detected {available_gpus} GPU(s) available in container")
        
        # Select recipe with actual GPU count
        recipe = selector.select_recipe(model_id, available_gpus, "bf16", "vllm")
        
        if recipe:
            # Get the specific configuration for available GPUs
            config = selector.get_recipe_config(recipe, available_gpus, "vllm")
            
            if config and 'args' in config:
                # Convert args dictionary to proper command line string
                vllm_args = convert_args_to_command_line(config['args'])
                
                if serve_mode:
                    # Direct execution mode - run vLLM server directly
                    print(f"Starting vLLM server for model: {model_id}")
                    print(f"Using {available_gpus} GPU(s)")
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
                print(f"No valid configuration found for model: {model_id} with {available_gpus} GPU(s)")
                sys.exit(1)
        else:
            print(f"No recipe found for model: {model_id} with {available_gpus} GPU(s)")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 