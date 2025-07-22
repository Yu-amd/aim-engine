# AIM Engine API Reference

## Overview

This document provides comprehensive API reference for the AIM (AMD Inference Microservice) Engine, including CLI commands, internal APIs, and integration interfaces.

## CLI Reference

### Main Commands

#### `aim-engine launch`

Launch an AI model with automatic configuration.

**Syntax**:
```bash
aim-engine launch <model_id> [gpu_count] [options]
```

**Parameters**:
- `model_id` (required): Hugging Face model identifier (e.g., `Qwen/Qwen3-32B`)
- `gpu_count` (optional): Number of GPUs to use (1, 2, 4, 8). Auto-detected if not specified.

**Options**:
- `--precision <format>`: Precision format (bf16, fp16, fp8, int8, int4)
- `--backend <engine>`: Backend engine (vllm, sglang)
- `--port <number>`: Port number for the endpoint (default: 8000)
- `--timeout <seconds>`: Timeout for endpoint readiness (default: 600)
- `--use-cache`: Use cached model if available
- `--no-cache`: Skip cache and download fresh model
- `--debug`: Enable debug mode
- `--config <file>`: Use custom configuration file

**Examples**:
```bash
# Basic launch with auto-detection
aim-engine launch Qwen/Qwen3-32B

# Launch with specific GPU count
aim-engine launch Qwen/Qwen3-32B 8

# Launch with specific precision
aim-engine launch Qwen/Qwen3-32B 8 --precision bf16

# Launch with custom port
aim-engine launch Qwen/Qwen3-32B 8 --port 8001

# Launch with debug mode
aim-engine launch Qwen/Qwen3-32B 8 --debug
```

#### `aim-engine list`

List available models, recipes, or configurations.

**Syntax**:
```bash
aim-engine list <type> [options]
```

**Types**:
- `models`: List available models
- `recipes`: List available recipes
- `configs`: List available configurations

**Examples**:
```bash
# List all models
aim-engine list models

# List recipes for specific model
aim-engine list recipes --filter "qwen"

# List configurations in JSON format
aim-engine list configs --format json
```

#### `aim-engine show-config`

Display configuration for a specific model.

**Syntax**:
```bash
aim-engine show-config <model_id> [options]
```

**Examples**:
```bash
# Show all configurations for model
aim-engine show-config Qwen/Qwen3-32B

# Show specific GPU configuration
aim-engine show-config Qwen/Qwen3-32B --gpu-count 8

# Show configuration in JSON format
aim-engine show-config Qwen/Qwen3-32B --format json
```

### Cache Management Commands

#### `aim-engine cache stats`

Display cache statistics.

**Examples**:
```bash
# Show cache statistics
aim-engine cache stats

# Show in JSON format
aim-engine cache stats --format json
```

#### `aim-engine cache list`

List cached models.

**Examples**:
```bash
# List all cached models
aim-engine cache list

# List models matching pattern
aim-engine cache list --filter "qwen"
```

#### `aim-engine cache download`

Download model to cache.

**Examples**:
```bash
# Download model to cache
aim-engine cache download Qwen/Qwen3-32B

# Force re-download
aim-engine cache download Qwen/Qwen3-32B --force
```

### Debug Commands

#### `aim-engine debug gpu-info`

Display GPU information.

**Examples**:
```bash
# Show basic GPU information
aim-engine debug gpu-info

# Show detailed information
aim-engine debug gpu-info --detailed
```

#### `aim-engine debug recipe-info`

Display recipe information.

**Examples**:
```bash
# Show recipe information
aim-engine debug recipe-info Qwen/Qwen3-32B

# Show specific configuration
aim-engine debug recipe-info Qwen/Qwen3-32B --gpu-count 8
```

## Internal API Reference

### AIMEngine Class

Main orchestrator class for the AIM Engine.

#### Methods

##### `launch_model`

```python
def launch_model(self, model_id: str, gpu_count: Optional[int] = None,
                precision: Optional[str] = None, backend: str = 'vllm',
                port: int = 8000, timeout: int = 600, use_cache: bool = True,
                debug: bool = False) -> Dict[str, Any]:
    """
    Launch an AI model with automatic configuration.
    
    Args:
        model_id: Hugging Face model identifier
        gpu_count: Number of GPUs to use
        precision: Precision format
        backend: Backend engine
        port: Port number for endpoint
        timeout: Timeout for endpoint readiness
        use_cache: Use cached model if available
        debug: Enable debug mode
    
    Returns:
        Dictionary with launch information
    """
```

##### `list_models`

```python
def list_models(self, format: str = 'table') -> List[Dict[str, Any]]:
    """
    List available models.
    
    Args:
        format: Output format
    
    Returns:
        List of model information
    """
```

### AIMRecipeSelector Class

Intelligent recipe and GPU selection.

#### Methods

##### `get_optimal_configuration`

```python
def get_optimal_configuration(self, model_id: str, 
                            customer_gpu_count: Optional[int] = None,
                            customer_precision: Optional[str] = None,
                            backend: str = 'vllm') -> Optional[Dict[str, Any]]:
    """
    Get optimal configuration for a model.
    
    Args:
        model_id: Model identifier
        customer_gpu_count: Customer specified GPU count
        customer_precision: Customer specified precision
        backend: Backend engine
    
    Returns:
        Optimal configuration or None
    """
```

##### `_detect_vllm_gpus`

```python
def _detect_vllm_gpus(self) -> int:
    """
    Detect GPUs that vLLM can use.
    
    Returns:
        Number of vLLM-compatible GPUs
    """
```

### AIMConfigGenerator Class

Configuration generation for different backends.

#### Methods

##### `generate_config`

```python
def generate_config(self, recipe: Dict[str, Any], gpu_count: int,
                   backend: str = 'vllm') -> Optional[Dict[str, Any]]:
    """
    Generate configuration for a recipe.
    
    Args:
        recipe: Recipe dictionary
        gpu_count: Number of GPUs
        backend: Backend engine
    
    Returns:
        Generated configuration or None
    """
```

### AIMDockerManager Class

Container and process lifecycle management.

#### Methods

##### `run_command_directly`

```python
def run_command_directly(self, config: Dict[str, Any], 
                        container_name: str, gpu_count: int) -> Dict[str, Any]:
    """
    Run command directly as subprocess.
    
    Args:
        config: Command configuration
        container_name: Name for the process
        gpu_count: Number of GPUs
    
    Returns:
        Process information
    """
```

## Environment Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CACHE_DIR` | `/workspace/model-cache` | Model cache directory |
| `DOCKER_SOCKET` | `/var/run/docker.sock` | Docker socket path |
| `DEFAULT_PORT` | `8000` | Default endpoint port |
| `DEFAULT_TIMEOUT` | `600` | Default timeout in seconds |

### Debug and Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `AIM_DEBUG` | `0` | Enable debug mode (1) |
| `LOG_LEVEL` | `INFO` | Logging level |
| `LOG_FORMAT` | `json` | Log format (json, text) |

## Error Codes

### CLI Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | General error |
| `2` | Configuration error |
| `3` | GPU detection error |
| `4` | Model launch error |
| `5` | Cache error |
| `6` | Network error |
| `7` | Permission error |

## Response Formats

### Success Response

```json
{
  "success": true,
  "data": {
    "container_id": "abc123",
    "container_name": "aim-qwen-32b",
    "endpoint_url": "http://localhost:8000",
    "gpu_count": 8,
    "precision": "bf16",
    "backend": "vllm",
    "status": "running"
  },
  "message": "Model launched successfully"
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "GPU_DETECTION_FAILED",
    "message": "Failed to detect GPUs",
    "details": "No GPUs found in container"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Integration Examples

### Python Integration

```python
from aim_launcher import AIMEngine

# Initialize AIM Engine
aim = AIMEngine(cache_dir="/workspace/model-cache", debug=True)

# Launch model
result = aim.launch_model(
    model_id="Qwen/Qwen3-32B",
    gpu_count=8,
    precision="bf16",
    port=8000
)

if result["success"]:
    print(f"Model launched: {result['data']['endpoint_url']}")
else:
    print(f"Launch failed: {result['error']['message']}")
```

### REST API Integration

```python
import requests

# Check endpoint health
response = requests.get("http://localhost:8000/health")
if response.status_code == 200:
    print("Endpoint is healthy")

# Make inference request
response = requests.post(
    "http://localhost:8000/v1/completions",
    json={
        "prompt": "Hello, how are you?",
        "max_tokens": 100
    }
)
print(response.json())
```

This API reference provides comprehensive documentation for all AIM Engine interfaces. For additional examples and use cases, refer to the other documentation files.
