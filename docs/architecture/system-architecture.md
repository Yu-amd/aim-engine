# AIM Engine - System Architecture

## 🎯 **Overview**

AIM Engine is designed as a modular, extensible system for intelligent AI model deployment. The architecture follows a clean separation of concerns with distinct components handling different aspects of the deployment process.

## 🏗️ **High-Level Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    AIM Engine System                        │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Recipe        │  │   Docker        │  │   Endpoint  │ │
│  │   Selector      │  │   Manager       │  │   Manager   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Config        │  │   vLLM          │  │   Unified   │ │
│  │   Generator     │  │   Container     │  │   Container │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Core Components**

### **1. AIM Recipe Selector (`aim_recipe_selector.py`)**

**Purpose**: Intelligent recipe selection and model-specific loading

**Key Features**:
- Model-specific recipe loading (efficient memory usage)
- Auto-detection of available GPUs
- Optimal configuration selection based on heuristics
- Fallback mechanisms for alternative configurations

**Responsibilities**:
- Load and validate AIM recipes
- Detect system resources (GPUs, memory)
- Select optimal configurations based on model size
- Provide fallback options when primary choice fails

**Key Methods**:
```python
class AIMRecipeSelector:
    def get_optimal_configuration(self, model_id, gpu_count=None, precision=None, backend='vllm')
    def _detect_available_gpus(self)
    def _get_optimal_gpu_count(self, model_id, available_gpus, customer_gpu_count=None)
    def _select_best_precision(self, model_id, customer_precision=None)
    def _load_model_recipes(self, model_id)
```

### **2. AIM Docker Manager (`aim_docker_manager.py`)**

**Purpose**: Container lifecycle management and Docker operations

**Key Features**:
- Docker container creation, management, and monitoring
- GPU resource allocation and configuration
- Port mapping and networking setup
- Container health monitoring

**Responsibilities**:
- Launch Docker containers with proper configuration
- Manage container lifecycle (start, stop, restart)
- Monitor container status and health
- Handle Docker image pulling and caching

**Key Methods**:
```python
class AIMDockerManager:
    def launch_container(self, config, container_name, gpu_count)
    def stop_container(self, container_name)
    def list_containers(self)
    def get_container_status(self, container_name)
    def pull_image(self, image_name)
```

### **3. AIM Config Generator (`aim_config_generator.py`)**

**Purpose**: Configuration generation for different deployment scenarios

**Key Features**:
- Generate Docker command arguments from recipes
- Create environment variables and volume mounts
- Configure networking and port mapping
- Support for different deployment modes

**Responsibilities**:
- Convert recipe configurations to Docker commands
- Generate environment variables for model serving
- Create volume mounts for model storage
- Configure networking and security settings

**Key Methods**:
```python
class AIMConfigGenerator:
    def generate_config(self, recipe_config, gpu_count, precision, backend, port=8000)
    def generate_docker_command(self, config)
    def generate_environment_vars(self, config)
    def generate_volume_mounts(self, config)
```

### **4. AIM Endpoint Manager (`aim_endpoint_manager.py`)**

**Purpose**: Endpoint validation, health checks, and monitoring

**Key Features**:
- Comprehensive endpoint validation
- Health check mechanisms
- Performance monitoring
- Inference testing

**Responsibilities**:
- Validate endpoint readiness
- Perform health checks on running endpoints
- Monitor endpoint performance
- Test inference capabilities

**Key Methods**:
```python
class AIMEndpointManager:
    def wait_for_endpoint_ready(self, endpoint_url, timeout=300)
    def perform_health_check(self, endpoint_url)
    def test_inference(self, endpoint_url, model_name)
    def monitor_performance(self, endpoint_url)
```

### **5. AIM Launcher (`aim_launcher.py`)**

**Purpose**: Main orchestration and user interface

**Key Features**:
- Command-line interface for user interaction
- Orchestration of all components
- Error handling and logging
- Deployment workflow management

**Responsibilities**:
- Parse user commands and validate inputs
- Orchestrate the deployment workflow
- Handle errors and provide user feedback
- Manage the overall deployment process

**Key Methods**:
```python
class AIMEngine:
    def launch_model(self, model_id, gpu_count=None, precision=None, backend='vllm', port=8000)
    def stop_model(self, container_name)
    def list_models(self)
    def get_model_status(self, container_name)
    def show_model_configurations(self, model_id)
    def get_optimal_configuration(self, model_id, gpu_count=None, precision=None, backend='vllm')
```

## 🔄 **Data Flow Architecture**

### **1. Recipe Selection Flow**
```
User Input → Recipe Selector → Model Loading → Configuration Selection → Recipe Output
     ↓              ↓              ↓              ↓              ↓
Model ID    Load Model    Detect GPUs    Select Optimal    Return Recipe
GPU Count   Recipes      Auto-Select    Configuration     Configuration
Precision   Only         GPU Count      Based on          with Metadata
Backend     For Model    Auto-Select    Heuristics        and Fallbacks
            Precision
```

### **2. Configuration Generation Flow**
```
Recipe Config → Config Generator → Docker Config → Container Launch → Endpoint Ready
      ↓              ↓              ↓              ↓              ↓
Recipe Data    Generate Cmd    Docker Args    Launch Container   Health Check
GPU Count      Args            Env Vars       GPU Access         Validation
Precision      Env Vars        Volumes        Port Mapping       Testing
Backend        Volumes         Networking     Resource Limits    Monitoring
```

### **3. Deployment Workflow**
```
User Command → Input Validation → Auto-Detection → Recipe Selection → Config Generation → Container Launch → Health Check → Success Response
     ↓              ↓              ↓              ↓              ↓              ↓              ↓              ↓
Parse Args    Validate Inputs   Detect GPUs    Load Recipes    Generate Cmd   Launch Docker   Check Health   Return Info
Validate      Check Model       Auto-Select    Select Best     Create Config  Setup GPU      Test Inference  Provide Usage
Model ID      GPU Count         Precision      Recipe          Setup Network  Setup Ports    Monitor Perf    Instructions
```

## 🎯 **Design Principles**

### **1. Modularity**
- Each component has a single, well-defined responsibility
- Components communicate through well-defined interfaces
- Easy to extend or replace individual components

### **2. Efficiency**
- Model-specific recipe loading (only load what's needed)
- Lazy loading of configurations
- Minimal memory footprint
- Fast startup times

### **3. Reliability**
- Comprehensive error handling
- Fallback mechanisms for configuration selection
- Health checks and validation
- Graceful degradation

### **4. Extensibility**
- Plugin architecture for new backends
- Configurable recipe formats
- Support for new deployment modes
- Easy to add new features

### **5. User Experience**
- Simple, intuitive command-line interface
- Intelligent auto-detection and selection
- Clear error messages and guidance
- Comprehensive logging and monitoring

## 🔧 **Configuration Management**

### **Recipe Structure**
```yaml
# Example AIM Recipe
recipe_id: qwen3-32b-mi300x-bf16
model_id: Qwen/Qwen3-32B
hardware:
  gpu_count: 4
  gpu_type: MI300X
  memory_requirement: 64GB
precision: bf16
backend: vllm
config:
  tensor_parallel_size: 4
  max_model_len: 8192
  gpu_memory_utilization: 0.9
  dtype: bfloat16
  trust_remote_code: true
```

### **Model Definition**
```yaml
# Example Model Definition
model_id: Qwen/Qwen3-32B
name: Qwen 3 32B
description: Qwen 3 32B parameter model
size: 32B
architecture: transformer
license: commercial
huggingface_url: https://huggingface.co/Qwen/Qwen3-32B
```

## 🐳 **Container Architecture**

### **Standard Container Model**
```
┌─────────────────┐    ┌─────────────────┐
│  AIM Engine     │    │  vLLM Container │
│  Container      │    │                 │
│                 │    │                 │
│ • Orchestration │    │ • Model Serving │
│ • Recipe Mgmt   │    │ • GPU Access    │
│ • Docker Mgmt   │    │ • Inference API │
└─────────────────┘    └─────────────────┘
        │                       │
        └─────── Docker ────────┘
```

### **Unified Container Model**
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

## 🔍 **Error Handling Architecture**

### **Error Categories**
1. **Input Validation Errors**: Invalid model ID, GPU count, etc.
2. **Resource Errors**: Insufficient GPUs, memory, etc.
3. **Configuration Errors**: No suitable recipe found
4. **Docker Errors**: Container launch failures, image pull issues
5. **Endpoint Errors**: Health check failures, inference errors

### **Error Handling Strategy**
- **Graceful Degradation**: Try alternative configurations
- **Fallback Mechanisms**: Use backup options when primary fails
- **Clear Error Messages**: Provide actionable guidance
- **Comprehensive Logging**: Detailed error information for debugging

## 📊 **Performance Architecture**

### **Optimization Strategies**
1. **Lazy Loading**: Only load recipes when needed
2. **Caching**: Cache Docker images and configurations
3. **Parallel Processing**: Concurrent operations where possible
4. **Resource Monitoring**: Real-time resource usage tracking

### **Scalability Considerations**
- **Horizontal Scaling**: Support for multiple nodes
- **Vertical Scaling**: Efficient use of available resources
- **Load Balancing**: Multiple endpoint instances
- **Resource Isolation**: Independent container management

## 🔒 **Security Architecture**

### **Security Measures**
1. **Container Isolation**: Each model runs in isolated container
2. **Resource Limits**: GPU and memory limits per container
3. **Network Security**: Port isolation and access control
4. **User Permissions**: Proper user and group management

### **Best Practices**
- Run containers as non-root users
- Use read-only filesystems where possible
- Implement proper logging and monitoring
- Regular security updates and patches

## 🎉 **Architecture Benefits**

### **For Users**
- **Simple Interface**: Easy-to-use command-line interface
- **Intelligent Defaults**: Automatic optimal configuration selection
- **Reliable Deployment**: Comprehensive validation and testing
- **Fast Deployment**: Optimized for quick model deployment

### **For System Administrators**
- **Resource Efficiency**: Optimal use of available hardware
- **Scalable Design**: Support for multiple concurrent models
- **Monitoring Ready**: Built-in health checks and metrics
- **Maintainable**: Clean, modular architecture

### **For Developers**
- **Extensible**: Easy to add new features and backends
- **Testable**: Each component can be tested independently
- **Well Documented**: Clear architecture and API documentation
- **Standards Compliant**: Follows best practices and conventions

---

**AIM Engine** - Intelligent AI Model Deployment Architecture! 🚀 