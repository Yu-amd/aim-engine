# AIM Engine + vLLM Combined Container Usage Guide

## Overview

This guide covers the recommended approach for using AIM Engine with vLLM in a combined container environment. The AIM Engine tools are installed directly into the `rocm/vllm` container, providing seamless integration and optimal performance.

## Architecture Benefits

- **Single Container**: No Docker-in-Docker complexity
- **Direct Integration**: AIM Engine tools available within vLLM environment
- **Optimal Performance**: No inter-container communication overhead
- **Simplified Deployment**: One container to build and manage
- **AMD/ROCm Native**: Optimized for AMD hardware

## Quick Start

### 1. Build the Combined Container

```bash
./build-aim-vllm.sh
```

### 2. Generate Optimal vLLM Command

```bash
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B
```

This will output the optimal Docker command for your model and hardware.

### 3. Run vLLM Server Directly

**Recommended Approach**: Use the interactive shell to run vLLM directly:

```bash
# Start interactive container
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell

# Inside the container, generate and run the command
aim-generate Qwen/Qwen3-32B
# Copy the generated command and run it directly
```

**Alternative**: Run the generated command directly:

```bash
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  rocm/vllm:latest \
  python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-32B --dtype bfloat16 --tensor-parallel-size 2 \
  --max-num-batched-tokens 16384 --max-model-len 32768 \
  --gpu-memory-utilization 0.9 --trust-remote-code true --port 8000
```

## Usage Patterns

### Pattern 1: Interactive Development (Recommended)

```bash
# Start interactive container
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell

# Inside container:
# 1. Generate optimal command
aim-generate Qwen/Qwen3-32B

# 2. Run vLLM server directly
python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-32B --dtype bfloat16 --tensor-parallel-size 2 \
  --max-num-batched-tokens 16384 --max-model-len 32768 \
  --gpu-memory-utilization 0.9 --trust-remote-code true --port 8000

# 3. Test the endpoint
curl -X POST "http://localhost:8000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Pattern 2: Automated Deployment

```bash
# Generate command and run in one step
docker run --rm -d \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  rocm/vllm:latest \
  bash -c "cd /workspace/aim-engine && \
    python3 aim_generate_command.py Qwen/Qwen3-32B | tail -n +2 | bash"
```

### Pattern 3: Custom Configuration

```bash
# Start interactive container
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-shell

# Inside container, use AIM Engine tools for custom configuration
python3 -c "
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
recipe = selector.select_recipe('Qwen/Qwen3-32B', 4, 'fp16', 'vllm')
print(f'Selected recipe: {recipe}')
"
```

## Available Commands

### `aim-generate <model_id>`
Generates the optimal Docker command for running vLLM with the specified model.

**Example:**
```bash
aim-generate Qwen/Qwen3-32B
```

### `aim-shell`
Starts an interactive shell with AIM Engine tools available.

**Example:**
```bash
aim-shell
```

### Direct Python Usage
Access AIM Engine functionality directly:

```python
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
recipe = selector.select_recipe('Qwen/Qwen3-32B', 2, 'bf16', 'vllm')
print(recipe)
```

## Advanced Usage

### Custom GPU Count and Precision

```bash
# Inside aim-shell, use custom parameters
python3 -c "
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
recipe = selector.select_recipe('Qwen/Qwen3-32B', 4, 'fp16', 'vllm')
print(f'Recipe: {recipe}')
"
```

### Model Information

```bash
# List available models
python3 -c "
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
models = selector.list_available_models()
print('Available models:', models)
"
```

### Recipe Validation

```bash
# Validate recipe exists
python3 -c "
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path

selector = AIMRecipeSelector(Path('.'))
exists = selector.validate_recipe_exists('Qwen/Qwen3-32B', 2, 'bf16', 'vllm')
print(f'Recipe exists: {exists}')
"
```

## Monitoring and Management

### Check Container Status

```bash
docker ps
docker logs <container_id>
```

### Monitor GPU Usage

```bash
# Inside container
rocm-smi
```

### Check vLLM Status

```bash
curl http://localhost:8000/health
```

## Benefits of This Approach

1. **Simplified Architecture**: Single container eliminates complexity
2. **Direct Access**: AIM Engine tools available within vLLM environment
3. **Optimal Performance**: No inter-container communication overhead
4. **Flexible Usage**: Interactive shell for development, automated for production
5. **AMD Optimized**: Native ROCm support with proper GPU detection

## Troubleshooting

### Container Exits Immediately
- Use `aim-shell` for interactive mode instead of `aim-serve`
- Check GPU availability with `rocm-smi`
- Verify port 8000 is not in use

### Model Not Found
- Check available models: `python3 -c "from aim_recipe_selector import AIMRecipeSelector; print(AIMRecipeSelector(Path('.')).list_available_models())"`
- Verify model ID spelling

### GPU Memory Issues
- Reduce `--gpu-memory-utilization` value
- Use fewer GPUs with `--tensor-parallel-size`
- Check available GPU memory with `rocm-smi`

### Port Conflicts
- Change host port mapping: `-p 8001:8000`
- Check for existing containers: `docker ps`

## Migration from Previous Approaches

### From Separate Containers
1. Stop existing AIM Engine container
2. Use `aim-generate` to get optimal vLLM command
3. Run vLLM directly with generated configuration

### From Direct vLLM
1. Use `aim-generate` to get optimized configuration
2. Replace manual vLLM arguments with generated ones
3. Benefit from automatic hardware detection and optimization

## Best Practices

1. **Use Interactive Mode**: `aim-shell` for development and testing
2. **Generate Commands**: Use `aim-generate` to get optimal configurations
3. **Monitor Resources**: Check GPU usage and memory consumption
4. **Cache Models**: Use volume mounts for model persistence
5. **Test Endpoints**: Verify API functionality after deployment

This approach provides the best of both worlds: the optimization capabilities of AIM Engine with the direct control and simplicity of running vLLM directly. 
