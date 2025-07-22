# AIM Engine Architecture

## Overview

The AIM (AMD Inference Microservice) Engine is designed as a modular, extensible framework for deploying AI models on AMD hardware. The architecture follows a layered approach with clear separation of concerns, enabling easy maintenance, testing, and extension.

## Core Components

### 1. AIM Launcher (`aim_launcher.py`)
- Main entry point and orchestration layer
- Parses command-line arguments and coordinates components
- Handles user interactions and error reporting

### 2. Recipe Selector (`aim_recipe_selector.py`)
- Intelligent recipe and GPU selection
- Detects available GPUs (vLLM → Container → Host → Fallback)
- Selects optimal recipes based on hardware and model requirements
- Handles fallback scenarios when optimal configurations aren't available

### 3. Config Generator (`aim_config_generator.py`)
- Generates backend-specific configurations
- Converts recipes to command configurations
- Handles argument validation and sanitization
- Supports multiple backends (vLLM, SGLang)

### 4. Docker Manager (`aim_docker_manager.py`)
- Container and process lifecycle management
- Executes commands directly (not Docker-in-Docker)
- Manages process lifecycle and monitoring
- Handles port mapping and resource allocation

### 5. Endpoint Manager (`aim_endpoint_manager.py`)
- Health monitoring and endpoint management
- Monitors endpoint health and readiness
- Handles timeout and retry logic
- Provides health status information

### 6. Cache Manager (`aim_cache_manager.py`)
- Model caching and storage management
- Manages model downloads and caching
- Provides cache statistics and cleanup
- Optimizes storage usage

## GPU Detection Strategy

1. **vLLM GPU Detection**: Uses PyTorch to detect GPUs that vLLM can actually use
2. **Container GPU Detection**: Checks GPUs visible inside the Docker container
3. **Host GPU Detection**: Uses rocm-smi/nvidia-smi to detect host GPUs
4. **Fallback Strategy**: Falls back to lower GPU counts (8→4→2→1) if optimal not available

## Data Flow

### Model Launch Flow
1. User Command → AIM Launcher
2. AIM Launcher → Recipe Selector
3. Recipe Selector → Config Generator
4. Config Generator → Docker Manager
5. Docker Manager → Endpoint Manager
6. Endpoint Manager → Model Ready

## Error Handling and Resilience

- **Graceful Degradation**: Automatically fall back to simpler configurations
- **Circuit Breaker**: Prevent cascading failures
- **Retry with Backoff**: Handle transient failures
- **Resource Cleanup**: Ensure proper cleanup on failures

## Extension Points

### Adding New Backends
- Implement backend interface
- Update config generator
- Add recipe support

### Adding New Hardware Support
- Update GPU detection
- Add hardware-specific recipes
- Update hardware selection logic

This architecture provides a solid foundation for the AIM Engine, enabling efficient model deployment, monitoring, and management on AMD hardware while maintaining flexibility for future extensions and improvements.
