# AIM Engine Bill of Materials (BOM)

## Overview

The AIM Engine container is a **hybrid unified container** that combines AMD ROCm vLLM capabilities with intelligent orchestration tools for deploying AI models on AMD hardware.

## Base Image

### Primary Base Image
- **Image**: `rocm/vllm:latest`
- **Description**: AMD ROCm vLLM container with PyTorch, vLLM, and ROCm support
- **Purpose**: Provides the core inference engine and GPU acceleration capabilities

## System Dependencies

### Package Manager Dependencies
```bash
# Installed via apt-get
curl                    # HTTP client for API interactions
wget                    # File download utility
git                     # Version control system
git-lfs                 # Git Large File Storage
docker.io               # Docker CLI and daemon
docker-compose          # Multi-container orchestration
gosu                    # Privilege escalation utility
```

### Python Dependencies
- **Source**: `requirements.txt`
- **Installation**: `pip install --no-cache-dir -r requirements.txt`
- **Location**: `/opt/aim-engine/requirements.txt`

## AIM Engine Core Components

### Python Modules
```
/opt/aim-engine/
├── aim_launcher.py           # Main entry point and orchestration
├── aim_recipe_selector.py    # Intelligent recipe and GPU selection
├── aim_config_generator.py   # Backend-specific configuration generation
├── aim_docker_manager.py     # Process lifecycle management
├── aim_endpoint_manager.py   # Endpoint health monitoring
├── aim_cache_manager.py      # Model caching and management
└── example_usage.py          # Usage examples and demonstrations
```

### Configuration Directories
```
/opt/aim-engine/
├── models/                   # Model definitions and specifications
├── recipes/                  # AIM recipes for different hardware/configurations
├── templates/                # Configuration templates
└── *.json                    # JSON configuration files
```

## Container Structure

### Directory Layout
```
aim-engine/
├── /opt/aim-engine/          # Main application directory
│   ├── aim_*.py              # Core AIM Engine modules
│   ├── models/               # Model definitions
│   ├── recipes/              # AIM recipes
│   ├── templates/            # Configuration templates
│   ├── requirements.txt      # Python dependencies
│   └── *.json               # Configuration files
├── /workspace/model-cache/   # Shared model cache directory
│   ├── models/               # Downloaded model files
│   ├── tokenizers/           # Model tokenizers
│   ├── configs/              # Model configurations
│   └── datasets/             # Dataset cache
└── /usr/local/bin/           # System binaries
```

### User and Permissions
- **User**: `aim-engine` (non-root user)
- **Group**: `aim-engine`
- **Cache Ownership**: `aim-engine:aim-engine`
- **Cache Permissions**: `755`

## Environment Variables

### Cache Configuration
```bash
HF_HOME=/workspace/model-cache                    # Hugging Face cache directory
TRANSFORMERS_CACHE=/workspace/model-cache         # Transformers library cache
HF_DATASETS_CACHE=/workspace/model-cache          # Datasets cache
VLLM_CACHE_DIR=/workspace/model-cache             # vLLM cache directory
HF_HUB_DISABLE_TELEMETRY=1                        # Disable telemetry
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512    # GPU memory allocation
AIM_CACHE_DIR=/workspace/model-cache              # AIM Engine cache directory
AIM_CACHE_ENABLED=1                              # Enable caching
```

### Path Configuration
```bash
PATH="/opt/aim-engine:$PATH"                      # Add AIM Engine to PATH
```

## Executable Scripts

### Entrypoint Script
- **File**: `/opt/aim-engine/entrypoint.sh`
- **Purpose**: Container initialization and startup
- **Features**:
  - Docker daemon checking
  - Cache initialization
  - Model pre-downloading (optional)
  - User switching (root to aim-engine)

### CLI Wrapper
- **File**: `/opt/aim-engine/aim-engine`
- **Purpose**: Enhanced command-line interface
- **Commands**:
  - `launch` - Orchestrated model deployment
  - `serve` - Direct vLLM serving
  - `cache` - Cache management
  - `list` - List running models
  - `stop` - Stop models
  - `status` - Model status

### Cache Initialization
- **File**: `/opt/aim-engine/init-cache.sh`
- **Purpose**: Cache directory setup and permissions

## Model Serving Architecture

### Process Execution Model
- **Approach**: Subprocess execution (not Docker-in-Docker)
- **Components**:
  - vLLM API server (`python -m vllm.entrypoints.openai.api_server`)
  - SGLang server (alternative backend)
  - AIM Engine orchestration processes

### GPU Access
- **Method**: Direct GPU access from container
- **Detection**: Multi-level GPU detection (vLLM, container, host)
- **Management**: Automatic tensor parallelism configuration

## Cache System

### Cache Structure
```
/workspace/model-cache/
├── models/                   # Model weights and files
├── tokenizers/               # Tokenizer files
├── configs/                  # Model configuration files
├── datasets/                 # Dataset cache
└── cache_index.json          # Cache metadata and index
```

### Cache Features
- **Shared Access**: Multiple processes use same cache
- **Automatic Management**: AIM Engine manages cache lifecycle
- **Pre-downloading**: Optional pre-download of common models
- **Cleanup**: Automatic cleanup of old models
- **Statistics**: Cache usage monitoring and reporting

## Security Considerations

### Container Security
- **Non-root User**: Runs as `aim-engine` user
- **Minimal Privileges**: Only necessary permissions
- **Resource Limits**: Configurable resource constraints
- **Network Isolation**: Limited network access

### Model Security
- **Trusted Sources**: Only load from verified sources
- **Access Control**: Proper file permissions
- **Validation**: Model integrity checking

## Performance Optimizations

### Memory Management
- **Shared Memory**: All components share container memory
- **GPU Memory**: Efficient GPU memory utilization
- **Cache Efficiency**: Shared model cache reduces redundancy

### Startup Optimization
- **Single Container**: No container orchestration overhead
- **Cached Models**: Faster startup with pre-cached models
- **Parallel Loading**: Concurrent model loading capabilities

## Monitoring and Observability

### Health Monitoring
- **Process Monitoring**: Subprocess health checks
- **Endpoint Monitoring**: API endpoint availability
- **Resource Monitoring**: GPU, memory, and CPU usage

### Logging
- **Structured Logging**: JSON-formatted logs
- **Log Levels**: Configurable (DEBUG, INFO, WARNING, ERROR)
- **Context Information**: Relevant context in log messages

### Metrics
- **Performance Metrics**: Response times, throughput
- **Resource Metrics**: GPU utilization, memory usage
- **Cache Metrics**: Hit rates, storage usage

## Extension Points

### Adding New Backends
1. Implement backend interface
2. Update config generator
3. Add recipe support
4. Update CLI commands

### Adding New Hardware Support
1. Update GPU detection logic
2. Add hardware-specific recipes
3. Update hardware selection logic

## Build Process

### Docker Build Steps
1. **Base Image**: Start with `rocm/vllm:latest`
2. **System Dependencies**: Install via apt-get
3. **Python Dependencies**: Install from requirements.txt
4. **AIM Engine Code**: Copy all Python modules
5. **Configuration**: Copy models, recipes, templates
6. **Scripts**: Create entrypoint and CLI scripts
7. **Permissions**: Set up user and permissions
8. **Environment**: Configure environment variables

### Build Artifacts
- **Image Name**: `aim-engine:latest`
- **Size**: Optimized for production deployment
- **Layers**: Efficient layer caching for rebuilds

## Deployment Considerations

### Resource Requirements
- **GPU**: AMD Instinct GPUs (MI250, MI300X, MI325X)
- **Memory**: Varies by model size and precision
- **Storage**: Cache directory for model storage
- **Network**: Internet access for model downloads

### Port Configuration
- **Default Port**: 8000 (configurable)
- **Health Check**: `/health` endpoint
- **API Endpoints**: OpenAI-compatible API

### Volume Mounts
- **Cache Volume**: `/workspace/model-cache`
- **Model Volume**: Optional custom model directory
- **Log Volume**: Optional log directory

## Troubleshooting

### Common Issues
- **GPU Detection**: Check ROCm installation and permissions
- **Cache Issues**: Verify cache directory permissions
- **Memory Issues**: Check GPU memory allocation
- **Network Issues**: Verify internet connectivity for model downloads

### Debug Commands
```bash
# Check GPU availability
rocm-smi

# Check container status
docker ps

# View container logs
docker logs <container_id>

# Check cache status
aim-engine cache stats

# Test GPU access
python -c "import torch; print(torch.cuda.device_count())"
```

---

This BOM provides a comprehensive overview of the AIM Engine container composition, enabling developers and operators to understand the complete system architecture and dependencies.
