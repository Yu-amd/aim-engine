# AIM Engine Architecture

## Overview

The AIM (AMD Inference Microservice) Engine is designed as a single-container solution that combines intelligent orchestration with direct model serving. The architecture follows a modular approach within a single container, enabling efficient deployment and management of AI models on AMD hardware.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AIM Engine Container                     │
│  (Single container with all components)                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 AIM Engine Core                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │ │
│  │  │   Launcher  │  │   Recipe    │  │     Cache       │ │ │
│  │  │             │  │  Selector   │  │    Manager      │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                               │
│  ┌───────────────────────────▼───────────────────────────────┐ │
│  │              Process Management                           │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │ │
│  │  │   Config    │  │   Docker    │  │    Endpoint     │ │ │
│  │  │ Generator   │  │   Manager   │  │    Manager      │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                               │
│  ┌───────────────────────────▼───────────────────────────────┐ │
│  │              Model Serving Process                        │ │
│  │  ┌─────────────────┐  ┌─────────────────┐                │ │
│  │  │     vLLM        │  │    SGLang       │                │ │
│  │  │   (Subprocess)  │  │   (Subprocess)  │                │ │
│  │  └─────────────────┘  └─────────────────┘                │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                    AMD Hardware                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   MI250 GPU     │  │   MI300X GPU    │  │   MI325X GPU │ │
│  │                 │  │                 │  │              │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Principles

### 1. Single Container Architecture
- **One Container**: All components run within a single Docker container
- **Direct Execution**: vLLM/SGLang run as subprocesses, not separate containers
- **Shared Resources**: All components share the same GPU access and memory
- **Simplified Deployment**: No Docker-in-Docker complexity

### 2. Process-Based Model Serving
- **Subprocess Execution**: Model serving engines run as child processes
- **Direct GPU Access**: Processes inherit GPU access from the main container
- **Resource Sharing**: All processes share the same container resources
- **Process Management**: AIM Engine manages the lifecycle of serving processes

### 3. Intelligent Orchestration
- **Automatic Configuration**: Smart detection and configuration selection
- **Fallback Strategies**: Graceful degradation when optimal configs aren't available
- **Resource Optimization**: Efficient use of available hardware resources

## Core Components

### 1. AIM Launcher (`aim_launcher.py`)

**Purpose**: Main entry point and orchestration layer

**Key Responsibilities**:
- Parse command-line arguments
- Initialize logging and configuration
- Coordinate between all components
- Handle user interactions and error reporting

**Key Methods**:
```python
class AIMEngine:
    def launch_model(self, model_id: str, gpu_count: Optional[int] = None, 
                    precision: Optional[str] = None, backend: str = 'vllm')
    def list_models(self)
    def show_config(self, model_id: str)
    def cache_stats(self)
```

### 2. Recipe Selector (`aim_recipe_selector.py`)

**Purpose**: Intelligent recipe and GPU selection

**Key Responsibilities**:
- Detect available GPUs (vLLM-compatible, container-visible, host)
- Select optimal recipes based on hardware and model requirements
- Handle fallback scenarios when optimal configurations aren't available
- Manage precision and backend selection

**Key Methods**:
```python
class AIMRecipeSelector:
    def get_optimal_configuration(self, model_id: str, customer_gpu_count: Optional[int] = None,
                                customer_precision: Optional[str] = None, backend: str = 'vllm')
    def _detect_vllm_gpus(self) -> int
    def _detect_container_gpus(self) -> int
    def _detect_available_gpus(self) -> int
    def select_best_recipe(self, model_id: str, gpu_count: Optional[int] = None,
                          precision: Optional[str] = None, backend: str = 'vllm')
```

**GPU Detection Strategy**:
1. **vLLM GPU Detection**: Uses PyTorch to detect GPUs that vLLM can actually use
2. **Container GPU Detection**: Checks GPUs visible inside the Docker container
3. **Host GPU Detection**: Uses rocm-smi to detect host GPUs
4. **Fallback Strategy**: Falls back to lower GPU counts (8→4→2→1) if optimal not available

### 3. Config Generator (`aim_config_generator.py`)

**Purpose**: Generate backend-specific configurations

**Key Responsibilities**:
- Convert recipes to backend-specific command configurations
- Handle argument validation and sanitization
- Generate environment variables and process parameters
- Support multiple backends (vLLM, SGLang)

**Key Methods**:
```python
class AIMConfigGenerator:
    def generate_config(self, recipe: Dict, gpu_count: int, backend: str = 'vllm')
    def _generate_vllm_config(self, recipe: Dict, gpu_count: int)
    def _generate_sglang_config(self, recipe: Dict, gpu_count: int)
    def _validate_arguments(self, args: Dict, backend: str)
```

### 4. Docker Manager (`aim_docker_manager.py`)

**Purpose**: Process lifecycle management within the container

**Key Responsibilities**:
- Execute commands directly as subprocesses (not Docker-in-Docker)
- Manage process lifecycle and monitoring
- Handle port binding and resource allocation
- Provide process information and status

**Key Methods**:
```python
class AIMDockerManager:
    def run_command_directly(self, config: Dict, container_name: str, gpu_count: int)
    def stop_container(self, container_id: str)
    def get_container_status(self, container_id: str)
    def get_container_logs(self, container_id: str)
```

**Important Design Decision**: The Docker Manager executes commands directly as subprocesses rather than launching nested Docker containers, avoiding the complexity of Docker-in-Docker.

### 5. Endpoint Manager (`aim_endpoint_manager.py`)

**Purpose**: Health monitoring and endpoint management

**Key Responsibilities**:
- Monitor endpoint health and readiness
- Handle timeout and retry logic
- Provide health status information
- Manage endpoint lifecycle

**Key Methods**:
```python
class AIMEndpointManager:
    def wait_for_endpoint_ready(self, endpoint_url: str, timeout: int = 600)
    def check_endpoint_health(self, endpoint_url: str)
    def get_endpoint_status(self, endpoint_url: str)
```

### 6. Cache Manager (`aim_cache_manager.py`)

**Purpose**: Model caching and storage management

**Key Responsibilities**:
- Manage model downloads and caching
- Provide cache statistics and cleanup
- Handle cache directory management
- Optimize storage usage

**Key Methods**:
```python
class AIMCacheManager:
    def get_cache_stats(self)
    def list_cached_models(self)
    def cleanup_cache(self, days: int = 30)
    def get_cache_directory(self)
```

## Data Flow

### Model Launch Flow

```
1. User Command
   ↓
2. AIM Launcher
   ├── Parse arguments
   ├── Initialize logging
   └── Call recipe selector
   ↓
3. Recipe Selector
   ├── Detect GPUs (vLLM → Container → Host)
   ├── Select optimal recipe
   └── Return configuration
   ↓
4. Config Generator
   ├── Generate backend config
   ├── Validate arguments
   └── Return command config
   ↓
5. Docker Manager
   ├── Execute command as subprocess
   ├── Return process info
   └── Start monitoring
   ↓
6. Endpoint Manager
   ├── Wait for endpoint ready
   ├── Monitor health
   └── Report status
   ↓
7. Model Ready (vLLM/SGLang process running)
```

### Process Execution Flow

```
1. Container Startup
   ├── Load AIM Engine components
   ├── Initialize cache and configuration
   └── Ready for commands
   ↓
2. Model Launch Request
   ├── Recipe selection and validation
   ├── Configuration generation
   └── Process execution
   ↓
3. Subprocess Launch
   ├── Start vLLM/SGLang as subprocess
   ├── Bind to specified port
   └── Monitor process health
   ↓
4. Model Serving
   ├── vLLM/SGLang serves model
   ├── AIM Engine monitors health
   └── Handle requests
```

## Container Architecture

### Container Structure

```
aim-engine:latest
├── /opt/aim-engine/           # AIM Engine code
│   ├── aim_*.py              # Core modules
│   ├── recipes/              # Recipe files
│   ├── models/               # Model definitions
│   └── templates/            # Configuration templates
├── /workspace/model-cache/   # Model cache directory
│   ├── models/               # Downloaded models
│   ├── tokenizers/           # Model tokenizers
│   └── configs/              # Model configurations
└── /usr/local/               # System dependencies
    ├── python/               # Python environment
    └── rocm/                 # ROCm runtime
```

### Process Hierarchy

```
Container (aim-engine:latest)
├── AIM Engine Process (aim_launcher.py)
│   ├── Recipe Selector
│   ├── Config Generator
│   ├── Cache Manager
│   └── Endpoint Manager
└── Model Serving Process (vLLM/SGLang)
    ├── Model Loading
    ├── GPU Memory Allocation
    └── Request Handling
```

## Configuration Management

### Recipe Structure

Recipes are YAML files that define model deployment configurations:

```yaml
recipe_id: qwen3-32b-mi300x-bf16
huggingface_id: Qwen/Qwen3-32B
precision: bf16
hardware: mi300x

vllm_serve:
  1_gpu:
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
  
  2_gpu:
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "2"
      --max-model-len: "32768"
      --gpu-memory-utilization: "0.9"
      --trust-remote-code: "true"
      --port: "8000"
```

### Environment Configuration

```bash
# Cache and storage
CACHE_DIR=/workspace/model-cache
DOCKER_SOCKET=/var/run/docker.sock

# Default settings
DEFAULT_PORT=8000
DEFAULT_TIMEOUT=600

# Debug and logging
AIM_DEBUG=0
LOG_LEVEL=INFO
```

## Deployment Architecture

### Single Container Deployment

```bash
# Basic deployment
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --cap-add=SYS_RAWIO \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 8
```

### Process Management

- **Single Container**: All components run in one container
- **Subprocess Execution**: vLLM/SGLang run as child processes
- **Shared GPU Access**: All processes share the same GPU devices
- **Port Binding**: Model serving processes bind to container ports
- **Health Monitoring**: AIM Engine monitors subprocess health

## Error Handling and Resilience

### Error Categories

1. **GPU Detection Errors**
   - Fallback to lower GPU counts
   - Graceful degradation to 1 GPU
   - Clear error messages

2. **Recipe Selection Errors**
   - Try alternative precision formats
   - Fallback to supported GPU counts
   - Provide helpful error messages

3. **Process Execution Errors**
   - Automatic cleanup on failure
   - Detailed error logging
   - Process status monitoring

4. **Endpoint Health Errors**
   - Configurable timeouts
   - Retry logic with exponential backoff
   - Health status reporting

### Resilience Patterns

1. **Graceful Degradation**: Automatically fall back to simpler configurations
2. **Process Recovery**: Restart failed subprocesses
3. **Resource Cleanup**: Ensure proper cleanup on failures
4. **Health Monitoring**: Continuous monitoring of serving processes

## Performance Considerations

### Single Container Benefits

- **Reduced Overhead**: No container orchestration overhead
- **Shared Memory**: All components share the same memory space
- **Direct GPU Access**: No GPU passthrough complexity
- **Faster Startup**: Single container startup vs. multiple containers

### Resource Optimization

- **GPU Memory**: Efficient sharing between AIM Engine and serving processes
- **System Memory**: Shared memory space reduces overall memory usage
- **CPU Resources**: No container scheduling overhead
- **Network**: Direct port binding without container networking

### Process Management

- **Subprocess Monitoring**: Direct monitoring of serving processes
- **Resource Sharing**: All processes share container resources
- **Faster Communication**: Inter-process communication within container
- **Simplified Debugging**: All processes visible in single container

## Security Considerations

### Container Security

- **Single Container**: Reduced attack surface
- **Minimal Privileges**: Run with minimal required permissions
- **Resource Limits**: Prevent resource exhaustion
- **Network Isolation**: Limit network access where possible

### Process Security

- **Subprocess Isolation**: Serving processes isolated from AIM Engine
- **Resource Limits**: Per-process resource limits
- **Access Control**: Proper file and network access controls

### Model Security

- **Trusted Sources**: Only load models from trusted sources
- **Code Verification**: Validate model code before execution
- **Access Control**: Implement proper access controls

## Extension Points

### Adding New Backends

1. **Implement Backend Interface**:
   ```python
   class NewBackend:
       def generate_config(self, recipe: Dict, gpu_count: int)
       def validate_arguments(self, args: Dict)
   ```

2. **Update Config Generator**:
   ```python
   def _generate_newbackend_config(self, recipe: Dict, gpu_count: int)
   ```

3. **Add Recipe Support**:
   ```yaml
   newbackend_serve:
     1_gpu:
       enabled: true
       args:
         --model: "model_name"
         --port: "8000"
   ```

### Adding New Hardware Support

1. **Update GPU Detection**:
   ```python
   def _detect_new_hardware_gpus(self) -> int
   ```

2. **Add Hardware-Specific Recipes**:
   ```yaml
   recipe_id: model-newhardware-precision
   hardware: newhardware
   ```

3. **Update Hardware Selection Logic**:
   ```python
   def _select_hardware_config(self, hardware: str)
   ```

## Monitoring and Observability

### Container Monitoring

- **Process Monitoring**: Monitor all subprocesses within container
- **Resource Usage**: Track container resource utilization
- **Health Checks**: Container-level health monitoring

### Process Monitoring

- **Subprocess Status**: Monitor vLLM/SGLang process health
- **Resource Usage**: Track per-process resource utilization
- **Error Handling**: Monitor and handle process failures

### Logging

- **Structured Logging**: JSON-formatted logs for easy parsing
- **Log Levels**: Configurable log levels (DEBUG, INFO, WARNING, ERROR)
- **Context Information**: Include relevant context in log messages

### Metrics

- **Performance Metrics**: Response times, throughput, resource usage
- **Health Metrics**: Endpoint health, error rates, availability
- **Resource Metrics**: GPU utilization, memory usage, temperature

### Health Checks

- **Endpoint Health**: Regular health check endpoints
- **Process Health**: Monitor process status and resource usage
- **Container Health**: Monitor container status and resource usage

## Advantages of Single Container Architecture

### Simplicity
- **Single Deployment Unit**: One container to build, deploy, and manage
- **Reduced Complexity**: No container orchestration or networking
- **Easier Debugging**: All components visible in single container
- **Simplified Monitoring**: Single point of monitoring and logging

### Performance
- **Reduced Overhead**: No container orchestration overhead
- **Shared Resources**: Efficient resource sharing between components
- **Direct Communication**: Fast inter-process communication
- **Optimized Memory**: Shared memory space reduces overall usage

### Reliability
- **Simplified Failure Handling**: Single container failure model
- **Easier Recovery**: Single container restart vs. multiple containers
- **Reduced Dependencies**: Fewer moving parts and dependencies
- **Better Resource Management**: Direct control over all resources

This single-container architecture provides a clean, efficient, and maintainable solution for deploying AI models on AMD hardware while maintaining all the intelligent orchestration capabilities of the AIM Engine.
