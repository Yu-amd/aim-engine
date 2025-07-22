# AIM Engine Installation Guide

## Overview

The AIM Engine installation process sets up a complete environment for deploying AI model inference endpoints using ROCm containers. The installation is designed to be **smart and efficient** - it only installs what's necessary and leverages the fact that the `rocm/vllm:latest` container already includes all model deployment dependencies.

## What the Installation Does

### 🔍 **1. Environment Validation**
- **Python Version Check**: Ensures Python 3.8+ is available
- **Docker Validation**: Verifies Docker is installed and the daemon is running
- **Virtual Environment Detection**: Checks if running in a virtual environment and provides guidance

### 📦 **2. Smart Dependency Management**
The installation uses **intelligent dependency checking** to only install what's missing:

#### **Core Python Dependencies (Installed Locally)**
- `PyYAML` - YAML file parsing for recipes and models
- `requests` - HTTP client for API calls and health checks
- `jsonschema` - JSON schema validation for configuration files

#### **Optional Dependencies (Not Required)**
- `docker` SDK - Alternative to subprocess for Docker operations
- `kubernetes` SDK - For future Kubernetes deployment features
- `prometheus-client` - For metrics collection

#### **Dependencies NOT Installed (Already in vLLM Container)**
- `vllm` - Model serving framework
- `torch` - PyTorch for model inference
- `transformers` - Hugging Face transformers library
- `accelerate` - Model acceleration utilities
- All CUDA/ROCm dependencies
- Model-specific dependencies

### 🐳 **3. Docker Image Management**
- **Smart Image Checking**: Only pulls `rocm/vllm:latest` if not already available
- **Base Container**: The vLLM container includes all necessary dependencies for model deployment
- **No Redundant Downloads**: Skips download if image already exists

### 🧪 **4. Comprehensive Testing**
- **Component Tests**: Validates each AIM Engine component (Recipe Selector, Config Generator, Docker Manager, Endpoint Manager)
- **Integration Tests**: Tests the complete workflow from recipe selection to configuration generation
- **Validation Tests**: Ensures input validation works correctly
- **Real Environment Testing**: Tests against actual Docker and system resources

### 📋 **5. Package Installation**
- **Development Mode**: Installs the AIM Engine in development mode for easy updates
- **Command Line Tools**: Makes `aim_launcher.py` available as a command-line tool
- **Module Availability**: Ensures all Python modules can be imported

## Installation Scripts

### **Option 1: Full Installation (`./install.sh`)**
```bash
./install.sh
```

**What it does:**
- ✅ Complete environment validation
- ✅ Smart dependency checking and installation
- ✅ Docker image management
- ✅ Package installation in development mode
- ✅ Comprehensive test suite execution
- ✅ Detailed installation summary

### **Option 2: Quick Start (`./scripts/quick_start.sh`)**
```bash
cd scripts && ./quick_start.sh
```

**What it does:**
- ✅ Basic environment validation
- ✅ Essential dependency installation
- ✅ Docker image verification
- ✅ Quick validation tests
- ✅ Usage examples and guidance

## Key Benefits of Smart Installation

### 🎯 **Efficiency**
- **No Redundant Installs**: Only installs missing dependencies
- **Leverages Container Dependencies**: Uses vLLM container's built-in dependencies
- **Fast Setup**: Minimal local installation required

### 🔧 **Flexibility**
- **Virtual Environment Support**: Works with or without virtual environments
- **System Package Handling**: Gracefully handles externally managed Python environments
- **Fallback Options**: Provides alternative installation methods if needed

### 🛡️ **Reliability**
- **Comprehensive Testing**: Validates the complete setup
- **Error Handling**: Provides clear error messages and solutions
- **Environment Detection**: Adapts to different system configurations

### 📈 **Scalability**
- **Minimal Local Footprint**: Only orchestration dependencies installed locally
- **Container-Based Deployment**: All model dependencies in containers
- **Easy Extension**: Designed for future Kubernetes deployment

## What You Get After Installation

### **✅ Ready-to-Use CLI Tool**
```bash
# Main launcher command
python3 aim_launcher.py --help

# Launch AI model endpoints
python3 aim_launcher.py --model Qwen/Qwen3-32B --gpus 4 --precision bf16 --backend vllm
```

### **✅ Development Environment**
```bash
# Available make commands
make help          # Show all commands
make test          # Run tests
make lint          # Code linting
make format        # Code formatting
make validate      # Validate YAML files
```

### **✅ Complete Documentation**
- `README.md` - Quick start guide
- `docs/AIM_IMPLEMENTATION_README.md` - Detailed documentation
- `PROJECT_SUMMARY.md` - Complete project overview

## Post-Installation Capabilities

After installation, you can:

1. **Deploy AI Models** - Launch inference endpoints for any supported model
2. **Scale Resources** - Configure 1-8 GPUs based on your hardware
3. **Optimize Performance** - Choose precision formats (fp16, bf16, fp8, int8, int4)
4. **Select Backends** - Use vLLM or sglang inference engines
5. **Monitor Endpoints** - Track health, performance, and metrics
6. **Manage Lifecycle** - Start, stop, and manage inference endpoints
7. **Extend Functionality** - Add new models, recipes, and configurations

## Troubleshooting

### **Virtual Environment Issues**
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate
./install.sh
```

### **Externally Managed Environment**
```bash
# Use --break-system-packages flag
pip3 install -r requirements.txt --break-system-packages
```

### **Docker Issues**
```bash
# Check Docker status
docker info

# Pull image manually
docker pull rocm/vllm:latest
```

### **Test Failures**
- Some tests may fail if Docker containers are not available
- Core functionality should still work for basic operations
- Check Docker daemon status and permissions

## Summary

The AIM implementation installation is designed to be **smart, efficient, and reliable**. It:

- ✅ **Only installs what's necessary** - leverages container dependencies
- ✅ **Validates everything** - ensures the complete setup works
- ✅ **Provides clear guidance** - helps users understand what's happening
- ✅ **Handles edge cases** - works in various environments
- ✅ **Sets up for success** - ready for immediate model deployment

The result is a complete AI model serving platform that can automatically deploy and manage inference endpoints based on customer specifications, with minimal local installation overhead. 