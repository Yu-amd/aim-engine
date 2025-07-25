# AIM Engine Design Document

---

## **Table of Contents**

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [System Architecture](#system-architecture)
4. [Core Components](#core-components)
5. [Model Caching System](#model-caching-system)
6. [Recipe Selection Engine](#recipe-selection-engine)
7. [Performance Optimization](#performance-optimization)
8. [Deployment Models](#deployment-models)
9. [Roadmap](#roadmap)

---

## **Executive Summary**

**AIM** (AMD Inference Microservice) is a comprehensive framework for deploying and serving AI models on AMD hardware, specifically designed for AMD Instinct™ GPUs (MI250, MI300X, MI325X, MI355X, etc.). **AIM** provides standardized recipes and configurations for efficient model inference across different hardware configurations and precision formats.

**AIM Engine** is an intelligent AI model deployment system that automatically optimizes large language model serving on AMD hardware. It combines intelligent recipe selection, dynamic resource detection, and advanced caching to deliver optimal performance with zero configuration, serving as the essential dependency management and orchestration layer for AIM deployments.

### **Key Value Propositions**
- **AIM Engine**: Manages and orchestrates AIM deployments on AMD hardware.
- **Zero Configuration**: Works out-of-the-box with automatic optimization
- **Hardware Intelligence**: AMD GPU-aware optimization and resource allocation
- **Performance Optimization**: Up to 10x faster deployment with intelligent caching
- **Enterprise Ready**: Kubernetes, Helm, and KServe integration roadmap
- **Streaming Support**: Real-time response streaming for enhanced UX
- **Dependency Management**: Ensures all AIM deployment dependencies are met

### **Technical Highlights**
- **Unified Container**: AIM Engine tools integrated into vLLM ROCm container
- **Intelligent Caching**: Persistent model caching with significant speed improvement
- **Dynamic Optimization**: Model-size based GPU allocation and precision selection
- **Multi-Backend Support**: vLLM, SGLang (roadmap), and extensible backend architecture
- **Production Ready**: Comprehensive monitoring, logging, and health checks
- **Dependency Orchestration**: Manages all AIM deployment prerequisites and requirements

---

## **Architecture Overview**

### **High-Level Architecture**

```mermaid
graph TB
    subgraph "User Interface Layer"
        A[CLI Commands] --> B[Web Interface]
        C[API Endpoints] --> B
    end
    
    subgraph "AIM Engine Core"
        D[Recipe Selector] --> E[Config Generator]
        F[Cache Manager] --> E
        G[Resource Detector] --> D
    end
    
    subgraph "Backend Runtime"
        H[vLLM Runtime] --> I[Model Serving]
        J[SGLang Runtime] --> I
        K[Custom Backends] --> I
    end
    
    subgraph "Hardware Layer"
        L[AMD GPUs] --> M[ROCm Runtime]
        N[System Memory] --> M
        O[Storage Cache] --> M
    end
    
    B --> D
    E --> H
    E --> J
    H --> L
    J --> L
```

### **AIM Container Architecture**

```mermaid
graph LR
    subgraph "AIM-vLLM Container"
        A[AIM Engine Tools] --> B[vLLM Runtime]
        C[Model Cache] --> B
        D[Recipe Database] --> A
        E[Resource Monitor] --> A
    end
    
    subgraph "Host System"
        F[AMD GPUs] --> G[ROCm Drivers]
        H[Model Storage] --> I[Cache Volume]
    end
    
    B --> G
    C --> I
```

---

## **System Architecture**

### **AIM Engine**

**AIM Engine** provides the essential orchestration and dependency management layer for AIM (AMD Inference Microservice) deployments, and guarantees efficient and optimized AIM deployments on AMD hardware.

### **Component Architecture**

```mermaid
graph TD
    subgraph "AIM Engine Core"
        A[AIMRecipeSelector] --> B[AIMConfigGenerator]
        C[AIMCacheManager] --> B
        D[ResourceDetector] --> A
    end
    
    subgraph "Data Layer"
        E[Models Directory] --> A
        F[Recipes Directory] --> A
        G[Cache Directory] --> C
    end
    
    subgraph "Runtime Layer"
        H[vLLM Backend] --> I[Model Serving]
        J[SGLang Backend] --> I
        K[Custom Backends] --> I
    end
    
    subgraph "Hardware Layer"
        L[AMD GPUs] --> M[ROCm Runtime]
        N[System Memory] --> M
        O[Storage] --> G
    end
    
    B --> H
    B --> J
    H --> L
    J --> L
```

### **Data Flow Architecture**

```mermaid
sequenceDiagram
    participant U as User
    participant A as AIM Engine
    participant C as Cache Manager
    participant R as Recipe Selector
    participant V as vLLM Runtime
    participant G as GPU Hardware
    
    U->>A: Deploy Model Request
    A->>C: Check Cache Status
    C-->>A: Cache Hit/Miss
    
    alt Cache Miss
        A->>C: Download & Cache Model
        C-->>A: Model Cached
    end
    
    A->>R: Select Optimal Recipe
    R->>R: Detect GPU Resources
    R-->>A: Optimal Configuration
    
    A->>V: Generate vLLM Command
    V->>G: Initialize GPU Resources
    G-->>V: GPU Ready
    V-->>A: Server Started
    A-->>U: Deployment Complete
```

---

## **Core Components**

### **1. AIMRecipeSelector**

**Purpose**: Intelligent recipe selection and resource optimization.

**Key Features**:
- Multi-level GPU detection (vLLM → Container → Host)
- Model-size based optimization
- Dynamic precision selection
- Fallback strategy management

**Architecture**:
```python
class AIMRecipeSelector:
    def __init__(self):
        self.models = self._load_models()
        self.recipes = self._load_recipes()
    
    def get_optimal_configuration(self, model_id, gpu_count=None, precision=None):
        # 1. Resource Detection
        available_gpus = self._detect_gpus()
        
        # 2. Model Analysis
        model_info = self.models.get(model_id, {})
        model_size = model_info.get('size', 'unknown')
        
        # 3. Optimization
        optimal_gpus = self._optimize_gpu_count(model_size, available_gpus, gpu_count)
        optimal_precision = self._optimize_precision(model_size, precision)
        
        # 4. Recipe Selection
        recipe = self._select_recipe(model_id, optimal_gpus, optimal_precision)
        
        return recipe
```

### **2. AIMConfigGenerator**

**Purpose**: Generates deployment configurations from selected recipes

**Key Features**:
- vLLM command generation
- Environment variable setup
- Docker configuration creation
- Resource allocation optimization

**Architecture**:
```python
class AIMConfigGenerator:
    def generate_deployment_config(self, recipe, model_id, port=8000):
        # 1. Command Generation
        vllm_command = self._build_vllm_command(recipe, port)
        
        # 2. Environment Setup
        env_vars = self._build_environment(recipe)
        
        # 3. Resource Allocation
        resource_config = self._allocate_resources(recipe)
        
        # 4. Cache Integration
        cache_config = self._integrate_cache(model_id)
        
        return {
            'command': vllm_command,
            'environment': env_vars,
            'resources': resource_config,
            'cache': cache_config
        }
```

### **3. AIMCacheManager**

**Purpose**: Intelligent model caching and storage management

**Key Features**:
- Persistent model storage
- Cache metadata tracking
- Automatic cleanup
- Volume mount configuration

**Architecture**:
```python
class AIMCacheManager:
    def __init__(self, cache_dir="/workspace/model-cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_index = self._load_cache_index()
    
    def is_model_cached(self, model_id):
        return self.cache_index.get(model_id, {}).get('cached', False)
    
    def add_model_to_cache(self, model_id, model_path):
        # Copy model files
        cache_path = self._get_cache_path(model_id)
        shutil.copytree(model_path, cache_path)
        
        # Update metadata
        self._update_cache_index(model_id, cache_path)
    
    def get_cache_stats(self):
        return {
            'total_models': len(self.list_cached_models()),
            'total_size_gb': self._calculate_total_size(),
            'cache_hit_rate': self._calculate_hit_rate()
        }
```

---

## **Model Caching System**

### **AIM Caching**

**AIM Engine** delivers comprehensive caching for AIM deployments. The caching system ensures that model dependencies are efficiently managed and reused across deployments.

### **Cache Architecture**

```mermaid
graph TB
    subgraph "Cache Manager"
        A[Cache Index] --> B[Cache Operations]
        C[Cache Statistics] --> B
        D[Cache Cleanup] --> B
    end
    
    subgraph "Cache Storage"
        E[Model Files] --> F[Tokenizer Files]
        G[Config Files] --> F
        H[Dataset Files] --> F
    end
    
    subgraph "Cache Metadata"
        I[Model Info] --> J[Size Tracking]
        K[Version Control] --> J
        L[Access Patterns] --> J
    end
    
    B --> E
    B --> I
    E --> J
```

### **Cache Performance Benefits**

| Metric | First Deployment | Cached Deployment | Improvement |
|--------|------------------|-------------------|-------------|
| **Download Time** | 30-60 minutes | 0 minutes | ∞ |
| **Setup Time** | 5-10 minutes | 30 seconds | 10-20x |
| **Network Usage** | 10-100 GB | 0 GB | 100% |
| **Reliability** | Network dependent | Local only | 100% |

### **Cache Management Operations**

## **Recipe Selection Engine**

### **AIM Recipe Selection**

**AIM Engine** provides AMD-specific optimization through intelligent recipe selection. The recipe engine ensures that AIM deployments are configured optimally for AMD GPUs, delivering leadership performance.

### **Recipe Selection Algorithm**

```mermaid
flowchart TD
    A[Model ID Input] --> B[Resource Detection]
    B --> C[Model Analysis]
    C --> D[GPU Count Optimization]
    D --> E[Precision Selection]
    E --> F[Recipe Matching]
    F --> G{Recipe Found?}
    G -->|Yes| H[Return Recipe]
    G -->|No| I[Fallback Strategy]
    I --> J[Try Lower GPU Count]
    J --> K[Try Different Precision]
    K --> L[Try Alternative Backend]
    L --> F
```

### **Optimization Strategies**

#### **Model-Size Based Optimization**

| Model Size | Optimal GPUs | Precision | Memory Utilization | Batch Tokens |
|------------|--------------|-----------|-------------------|--------------|
| **7B-8B** | 1 | fp16 | 85% | 8,192 |
| **13B-14B** | 2 | bf16 | 90% | 16,384 |
| **32B-34B** | 4 | bf16 | 90% | 32,768 |
| **70B+** | 8 | bf16 | 90% | 65,536 |

#### **Hardware-Specific Optimization**

```yaml
# MI300X Optimization
mi300x_config:
  gpu_memory_utilization: 0.9
  max_model_len: 32768
  tensor_parallel_size: auto
  dtype: bfloat16

# MI325X Optimization  
mi325x_config:
  gpu_memory_utilization: 0.95
  max_model_len: 65536
  tensor_parallel_size: auto
  dtype: bfloat16
```

### **Recipe Structure**

```yaml
recipe_id: qwen3-32b-mi300x-bf16
model_id: Qwen/Qwen3-32B
hardware: MI300X
precision: bf16
readiness_level: production

vllm_serve:
  1_gpu:
    enabled: true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --max-num-batched-tokens: 8192
      --max-model-len: 32768
      --gpu-memory-utilization: 0.9
      --trust-remote-code: true
  
  2_gpu:
    enabled: true
    args:
      --tensor-parallel-size: 2
      --max-num-batched-tokens: 16384
      --max-model-len: 32768
      --gpu-memory-utilization: 0.9
      --trust-remote-code: true
  
  4_gpu:
    enabled: true
    args:
      --tensor-parallel-size: 4
      --max-num-batched-tokens: 32768
      --max-model-len: 32768
      --gpu-memory-utilization: 0.9
      --trust-remote-code: true
```

---

## **Performance Optimization**

### **Optimization Techniques**

1. **Dynamic Batching**: Automatic batch size adjustment based on GPU count
2. **Tensor Parallelism**: Automatic scaling with GPU count
3. **Memory Pinning**: Optimized memory allocation for AMD GPUs
4. **Precision Selection**: Hardware-aware precision choices
5. **Cache Optimization**: Intelligent model caching and prefetching

---

## **Deployment Models**

### **Current Deployment: Container-Based**

```bash
# Single Container Deployment
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B
```

### **Future Deployment: Kubernetes**

```yaml
# Kubernetes Deployment (Roadmap)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aim-engine-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: aim-engine
  template:
    metadata:
      labels:
        app: aim-engine
    spec:
      containers:
      - name: aim-engine
        image: aim-vllm:latest
        ports:
        - containerPort: 8000
        resources:
          limits:
            nvidia.com/gpu: 4
        volumeMounts:
        - name: model-cache
          mountPath: /workspace/model-cache
      volumes:
      - name: model-cache
        persistentVolumeClaim:
          claimName: model-cache-pvc
```

---

## **Roadmap**

### **Phase 1: Q4 2025 - Enterprise Readiness**

#### **Kubernetes Integration**
- [ ] **Helm Charts**: Complete Helm chart for AIM Engine deployment
- [ ] **KServe Integration**: Native KServe backend support
- [ ] **Multi-Node Support**: Distributed deployment across multiple nodes
- [ ] **Resource Management**: Kubernetes resource quotas and limits

#### **Enhanced Monitoring**
- [ ] **Prometheus Metrics**: Comprehensive metrics collection
- [ ] **Grafana Dashboards**: Real-time performance monitoring
- [ ] **Health Checks**: Kubernetes liveness and readiness probes
- [ ] **Logging**: Structured logging with ELK stack integration

### **Phase 2: Q1 2026 - Advanced Features**

#### **Multi-Backend Support**
- [ ] **SGLang Integration**: Native SGLang backend support
- [ ] **Custom Backends**: Plugin architecture for custom backends
- [ ] **Backend Comparison**: Performance comparison tools
- [ ] **Dynamic Backend Switching**: Runtime backend selection

#### **Fraction GPU Resource Recipes**
- [ ] **Partial GPU Allocation**: Support for fractional GPU resource allocation
- [ ] **Multi-Model GPU Sharing**: Multiple models sharing single GPU resources
- [ ] **GPU Memory Partitioning**: Intelligent GPU memory allocation for concurrent models
- [ ] **Resource Isolation**: Secure isolation between models sharing GPU resources

#### **Advanced Caching**
- [ ] **Distributed Caching**: Redis-based distributed cache
- [ ] **Cache Prefetching**: Intelligent model prefetching
- [ ] **Cache Compression**: Model compression for storage efficiency
- [ ] **Cache Analytics**: Advanced cache performance analytics

### **Phase 3: Q2 2026 - Production Features**

#### **High Availability**
- [ ] **Auto-scaling**: Horizontal Pod Autoscaler (HPA) support
- [ ] **Load Balancing**: Intelligent load balancing across replicas
- [ ] **Fault Tolerance**: Automatic failover and recovery
- [ ] **Disaster Recovery**: Backup and restore capabilities

#### **Security & Compliance**
- [ ] **RBAC Integration**: Role-based access control
- [ ] **Network Policies**: Kubernetes network policies
- [ ] **Secrets Management**: Secure credential management
- [ ] **Audit Logging**: Comprehensive audit trails

### **Phase 4: Q3 2026 - Enterprise Features**

#### **Multi-Tenancy**
- [ ] **Namespace Isolation**: Multi-tenant deployment support
- [ ] **Resource Quotas**: Per-tenant resource limits
- [ ] **Billing Integration**: Usage tracking and billing
- [ ] **Tenant Management**: Tenant lifecycle management

#### **Advanced Analytics**
- [ ] **Performance Analytics**: Advanced performance insights
- [ ] **Cost Optimization**: Cost analysis and optimization
- [ ] **Capacity Planning**: Predictive capacity planning
- [ ] **Business Intelligence**: BI dashboard integration

---

*Last updated: July 2025*
*Version: 1.0.0*
