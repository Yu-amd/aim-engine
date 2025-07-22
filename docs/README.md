# AIM Engine - Complete Documentation

## 🎯 **Overview**

AIM Engine is an intelligent AI model deployment system that automatically selects optimal configurations and manages inference endpoints using Docker containers. It combines the power of vLLM ROCm with intelligent orchestration tools.

## 🚀 **Quick Start**

### **Installation**
```bash
# Clone the repository
git clone <repository-url>
cd aim-engine

# Install dependencies
./install.sh

# Or install manually
pip install -e .
```

### **Basic Usage**
```bash
# Launch model with auto-detection
aim-engine launch Qwen/Qwen3-32B

# Launch with specific configuration
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --backend vllm

# List running endpoints
aim-engine list

# Stop an endpoint
aim-engine stop aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
```

## 📚 **Documentation Structure**

### **Guides**
- [Installation Guide](guides/installation.md) - Setup and installation instructions
- [User Guide](guides/user-guide.md) - How to use AIM Engine
- [Recipe Selection Guide](guides/recipe-selection.md) - Understanding recipe selection
- [Container Management](guides/container-management.md) - Working with containers

### **Architecture**
- [System Architecture](architecture/system-architecture.md) - Overall system design
- [Workflow](architecture/workflow.md) - Complete deployment workflow
- [Unified Container](architecture/unified-container.md) - Unified container approach
- [Production Deployment](architecture/production.md) - Production deployment guide

### **Examples**
- [Basic Examples](examples/basic-usage.md) - Simple usage examples
- [Advanced Examples](examples/advanced-usage.md) - Complex deployment scenarios
- [Troubleshooting](examples/troubleshooting.md) - Common issues and solutions

## 🔧 **Key Features**

### **1. Intelligent Auto-Detection**
- **GPU Detection**: Automatically detects available GPUs
- **Optimal Selection**: Chooses best configuration based on model size
- **Smart Fallback**: Tries alternatives if primary choice fails

### **2. Model-Specific Recipe Loading**
- **Efficient Loading**: Only loads recipes for the target model
- **Fast Startup**: Optimized for quick deployment
- **Memory Efficient**: Minimal memory footprint

### **3. Single Container Deployment**
- **Unified Container**: Single container with AIM Engine and vLLM
- **Subprocess Execution**: vLLM runs as child process for efficiency
- **Shared Resources**: All components share GPU access and memory

### **4. Production Ready**
- **Health Checks**: Comprehensive endpoint validation
- **Resource Management**: Efficient GPU and memory usage
- **Monitoring**: Built-in metrics and logging
- **Scalability**: Support for multiple concurrent models

## 🏗️ **System Architecture**


### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AIM Engine Container                     │
│   (aim-engine:latest - Unified vLLM + AIM Engine)           │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │                 AIM Engine Core                         │ │
│ │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │ │
│ │  │   Launcher  │  │   Recipe    │  │     Cache       │  │ │
│ │  │             │  │  Selector   │  │    Manager      │  │ │
│ │  └─────────────┘  └─────────────┘  └─────────────────┘  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│  ┌───────────────────────────▼────────────────────────────┐ │
│  │              Process Management                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │ │
│  │  │   Config    │  │   Docker    │  │    Endpoint     │ │ │
│  │  │ Generator   │  │   Manager   │  │    Manager      │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│                              │                              │
│  ┌───────────────────────────▼────────────────────────────┐ │
│  │              Model Serving Process                     │ │
│  │  ┌─────────────────┐  ┌─────────────────┐              │ │
│  │  │     vLLM        │  │    SGLang       │              │ │
│  │  │   (Subprocess)  │  │   (Subprocess)  │              │ │
│  │  └─────────────────┘  └─────────────────┘              │ │
│  └────────────────────────────────────────────────────────┘ │
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

### Container Components

**Base Image**: `rocm/vllm:latest`
- **vLLM Runtime**: High-performance inference engine
- **ROCm Support**: AMD GPU acceleration
- **Python Environment**: PyTorch, transformers, and ML libraries

**Added Components**:
- **AIM Engine Tools**: Orchestration and management modules
- **Docker CLI**: Container management capabilities
- **Cache System**: Model caching and storage
- **Process Management**: Subprocess execution for model serving

### Key Design Principles

1. **Unified Container**: Single container with all components
2. **Subprocess Execution**: vLLM/SGLang run as child processes
3. **Shared Resources**: All components share GPU access and memory
4. **Docker CLI Available**: For container management if needed
5. **Efficient Deployment**: No Docker-in-Docker overhead


## 🔄 **Complete Workflow**

### **Phase 1: Input Processing**
- Parse user command and validate inputs
- Initialize AIM Engine components

### **Phase 2: Auto-Detection & Resource Analysis**
- Detect available GPUs using `rocm-smi`
- Auto-select optimal GPU count based on model size
- Auto-select optimal precision based on model characteristics

### **Phase 3: Recipe Selection & Loading**
- Load ONLY recipes for the specific model
- Filter by precision, backend, GPU count
- Select best matching recipe

### **Phase 4: Configuration Generation**
- Generate Docker command arguments from recipe
- Create environment variables and volume mounts
- Configure networking and port mapping

### **Phase 5: Docker Container Management**
- Generate unique container name
- Pull `rocm/vllm:latest` image if needed
- Launch container with GPU access and configuration

### **Phase 6: Endpoint Readiness & Health Checks**
- Wait for container to start and vLLM to initialize
- Perform health checks on endpoint
- Verify model loading and GPU memory allocation

### **Phase 7: Validation & Testing**
- Send test inference request
- Verify response quality and performance
- Validate endpoint is ready for production use

### **Phase 8: Success Response & Monitoring**
- Return deployment information
- Setup monitoring and health check endpoints
- Provide usage instructions

## 🐳 **Container Deployment Models**

### **Model 1: Unified Container (Recommended)**
```
┌─────────────────────────────────────────────────────────────┐
│                    AIM Engine Unified Container             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   AIM Engine    │  │   vLLM ROCm     │  │   Docker    │ │
│  │ Orchestration   │  │   Base Image    │  │   CLI       │ │
│  │   Tools         │  │                 │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- Single container deployment
- Self-contained environment
- Dual mode operation (orchestration + direct serving)
- Easy distribution and deployment

### **Model 2: Separate Containers**
```
┌─────────────────┐    ┌─────────────────┐
│  AIM Engine     │    │  vLLM Container │
│  Container      │    │                 │
│                 │    │                 │
│ • Orchestration │    │ • Model Serving │
│ • Recipe Mgmt   │    │ • GPU Access    │
│ • Docker Mgmt   │    │ • Inference API │
└─────────────────┘    └─────────────────┘
```

**Benefits:**
- Resource isolation
- Independent scaling
- Better for multi-node deployment
- Microservices architecture

## 📊 **Performance Benefits**

### **Memory Efficiency**
- **Before**: Loads all recipes (could be hundreds)
- **After**: Loads only model-specific recipes (typically 1-5)

### **Startup Time**
- **Before**: ~100-500ms to load all recipes
- **After**: ~10-50ms to load model-specific recipes

### **Scalability**
- **Before**: Performance degrades with recipe count
- **After**: Consistent performance regardless of total recipe count

## 🎯 **Usage Examples**

### **Example 1: Full Auto-Detection**
```bash
# Launch model with complete auto-detection
aim-engine launch Qwen/Qwen3-32B

# What happens:
# 1. Detects available GPUs (e.g., 4 GPUs)
# 2. Auto-selects optimal GPU count (32B → 4 GPUs)
# 3. Auto-selects optimal precision (32B → bf16)
# 4. Loads only Qwen/Qwen3-32B recipes
# 5. Selects best matching recipe
# 6. Deploys with optimal configuration
```

### **Example 2: Customer Specified Configuration**
```bash
# Launch with specific GPU count and precision
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# What happens:
# 1. Uses customer specified GPU count (4 GPUs)
# 2. Uses customer specified precision (bf16)
# 3. Loads only Qwen/Qwen3-32B recipes
# 4. Selects best matching recipe for 4 GPUs + bf16
# 5. Deploys with customer configuration
```

### **Example 3: Unified Container Deployment**
```bash

## 🔍 **Configuration Selection Logic**

### **GPU Count Selection Priority**
1. **Customer specified** (if within available GPUs)
2. **Model size heuristic**:
   - 7B/8B models: 1 GPU
   - 13B/14B models: 2 GPUs
   - 32B/34B models: 4 GPUs
   - 70B/72B models: 8 GPUs
3. **Maximum available** (if heuristic exceeds available)

### **Precision Selection Priority**
1. **Customer specified**
2. **Model size heuristic**:
   - 7B/8B models: fp16 (faster, sufficient accuracy)
   - 13B+ models: bf16 (better numerical stability)
3. **Fallback alternatives** (if primary choice fails)

## 🛠️ **Development**

### **Project Structure**
```
aim-engine/
├── aim_*.py              # Core AIM Engine modules
├── models/               # Model definitions
├── recipes/              # AIM recipes
├── templates/            # Configuration templates
├── tests/                # Test files
├── scripts/              # Utility scripts
├── docs/                 # Documentation
├── Dockerfile            # Standard container
├── Dockerfile.unified    # Unified container
└── requirements.txt      # Python dependencies
```

### **Running Tests**
```bash
# Run all tests
python -m pytest tests/

# Run specific test
python tests/test_aim_implementation.py

# Run with coverage
python -m pytest tests/ --cov=.
```

### **Building Containers**
```bash
# Build standard container
docker build -t aim-engine:latest .

### **For Users**
- ✅ **Simple**: Just specify the model, everything else is automatic
- ✅ **Fast**: Complete deployment in minutes
- ✅ **Reliable**: Comprehensive validation and testing
- ✅ **Flexible**: Override any auto-selected option

### **For System Administrators**
- ✅ **Resource Efficient**: Uses available hardware optimally
- ✅ **Scalable**: Performance doesn't degrade with more models
- ✅ **Monitorable**: Detailed logging and health checks
- ✅ **Maintainable**: Clean, modular architecture

### **For Developers**
- ✅ **Extensible**: Easy to add new features and optimizations
- ✅ **Testable**: Each component can be tested independently
- ✅ **Documented**: Clear workflow and API documentation
- ✅ **Standards Compliant**: Follows best practices

## 📞 **Support**

For questions, issues, or contributions:
- Check the [troubleshooting guide](examples/troubleshooting.md)
- Review the [examples](examples/) for common use cases
- Open an issue on the project repository

---

**AIM Engine** - Intelligent AI Model Deployment Made Simple! 🚀 
