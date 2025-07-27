# AIM Engine Recipe-Aware Kubernetes Deployment

## **Implemented Features**

This document describes the 5 key features implemented for recipe-aware Kubernetes deployment of AIM Engine.

### **1. Recipe-Aware Helm Charts with Dynamic Configuration**

**Feature**: Helm charts that automatically configure deployments based on selected recipes.

**Implementation**:
- Dynamic resource allocation based on recipe requirements
- Automatic command and argument generation
- Environment variable configuration from recipe settings
- Support for both automatic and manual recipe selection

**Benefits**:
- Consistent deployment across environments
- Reduced configuration errors
- Automatic optimization based on hardware

### **2. Recipe Selection Hooks for Automatic Optimization**

**Feature**: Pre-deployment hooks that automatically select optimal recipes.

**Implementation**:
- Helm pre-install and pre-upgrade hooks
- Automatic GPU detection and resource analysis
- Model-specific recipe filtering
- Fallback mechanisms for optimal performance

**Benefits**:
- Zero-configuration deployments
- Automatic performance optimization
- Consistent recipe selection logic

### **3. Recipe Validation in Kubernetes Admission Controllers**

**Feature**: Kubernetes admission controllers that validate recipe configurations.

**Implementation**:
- Validating webhook for deployment validation
- Recipe compatibility checking
- Resource requirement validation
- Performance constraint verification

**Benefits**:
- Prevents invalid deployments
- Ensures resource compatibility
- Maintains deployment quality

### **4. Recipe-Based Monitoring and Alerting**

**Feature**: Comprehensive monitoring with recipe-specific metrics and alerts.

**Implementation**:
- Custom Prometheus metrics for recipe performance
- Recipe-specific alerting rules
- Performance baseline tracking
- Resource utilization monitoring

**Benefits**:
- Recipe performance visibility
- Proactive issue detection
- Performance optimization insights

### **5. Recipe Performance Dashboards**

**Feature**: Grafana dashboards for recipe performance visualization.

**Implementation**:
- Recipe selection overview panels
- Performance comparison charts
- Resource utilization graphs
- Optimization recommendation displays

**Benefits**:
- Visual performance insights
- Easy recipe comparison
- Optimization guidance

## **Quick Start**

### **Automatic Recipe Selection**
```bash
# Deploy with automatic recipe selection
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set aim_engine.model_id=Qwen/Qwen3-32B
```

### **Manual Recipe Override**
```bash
# Deploy with specific recipe configuration
helm install aim-engine ./helm \
  --set aim_engine.auto_select=false \
  --set aim_engine.gpu_count=4 \
  --set aim_engine.precision=bf16 \
  --set aim_engine.backend=vllm
```

### **Custom Recipe Configuration**
```bash
# Deploy with custom recipe parameters
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set aim_engine.overrides.gpu_count=8 \
  --set aim_engine.overrides.precision=fp16 \
  --set aim_engine.overrides.vllm_args.max_model_len=16384
```

### **Production Deployment**
```bash
# Deploy with monitoring and validation
helm install aim-engine ./helm \
  --set aim_engine.auto_select=true \
  --set monitoring.enabled=true \
  --set admission_controller.enabled=true \
  --set aim_engine.model_id=Qwen/Qwen3-32B
```

### **Verification**
```bash
# Check recipe selection
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# Verify deployment configuration
kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml

# Check monitoring setup
kubectl get servicemonitor -n aim-engine
kubectl get prometheusrule -n aim-engine
```

## **Configuration Options**

### **AIM Engine Configuration**
```yaml
aim_engine:
  # Automatic recipe selection
  auto_select: true
  
  # Model configuration
  model_id: "Qwen/Qwen3-32B"
  
  # Manual overrides (when auto_select=false)
  gpu_count: 4
  precision: "bf16"
  backend: "vllm"
  
  # Performance tuning
  performance:
    max_batch_size: 32
    max_input_length: 4096
    max_output_length: 2048
  
  # Hardware configuration
  hardware:
    gpu_type: "MI300X"
    memory_utilization: 0.9
    cpu_cores: 16
  
  # vLLM arguments
  vllm_args:
    max_model_len: 32768
    max_num_batched_tokens: 8192
    gpu_memory_utilization: 0.9
    trust_remote_code: true
  
  # Environment variables
  env_vars:
    VLLM_USE_ROCM: "1"
    PYTORCH_ROCM_ARCH: "gfx90a"
    HF_HUB_DISABLE_TELEMETRY: "1"
  
  # Overrides for auto-selection
  overrides:
    gpu_count: null  # Override auto-detected GPU count
    precision: null  # Override auto-selected precision
    backend: null    # Override auto-selected backend
    vllm_args: {}    # Additional vLLM arguments
    env_vars: {}     # Additional environment variables
```

### **Monitoring Configuration**
```yaml
monitoring:
  enabled: true
  
  # Prometheus configuration
  prometheus:
    enabled: true
    scrape_interval: "30s"
  
  # Grafana configuration
  grafana:
    enabled: true
    dashboard:
      enabled: true
      title: "AIM Engine Recipe Performance"
  
  # Alerting configuration
  alerting:
    enabled: true
    rules:
      - name: "AIMEngineRecipeNotFound"
        condition: "aim_recipe_selection_total{result='not_found'} > 0"
        severity: "warning"
      
      - name: "AIMEngineLowThroughput"
        condition: "aim_performance_tokens_per_second < 1000"
        severity: "warning"
```

### **Admission Controller Configuration**
```yaml
admission_controller:
  enabled: true
  
  # Webhook configuration
  webhook:
    failure_policy: "Fail"
    timeout_seconds: 30
  
  # Validation rules
  validation:
    check_resource_limits: true
    check_recipe_compatibility: true
    check_performance_constraints: true
```

## **Advanced Usage**

### **Custom Recipe Development**
```bash
# Create custom recipe
cat > custom-recipe.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-recipe
data:
  recipe.yaml: |
    recipe_id: custom-qwen-32b-4gpu-bf16
    huggingface_id: Qwen/Qwen3-32B
    hardware: MI300X
    gpu_count: 4
    precision: bf16
    backend: vllm
    config:
      args:
        max_model_len: 32768
        max_num_batched_tokens: 8192
        gpu_memory_utilization: 0.9
    performance:
      expected_tokens_per_second: 5000
      expected_latency_ms: 100
    resources:
      requests:
        amd.com/gpu: "4"
        memory: "64Gi"
        cpu: "16"
      limits:
        amd.com/gpu: "4"
        memory: "128Gi"
        cpu: "32"
EOF

# Apply custom recipe
kubectl apply -f custom-recipe.yaml -n aim-engine

# Deploy with custom recipe
helm install aim-engine ./helm \
  --set aim_engine.auto_select=false \
  --set aim_engine.custom_recipe=custom-recipe
```

### **Multi-Model Deployment**
```bash
# Deploy multiple models with different recipes
helm install aim-engine-qwen ./helm \
  --set aim_engine.model_id=Qwen/Qwen3-32B \
  --set aim_engine.gpu_count=4

helm install aim-engine-llama ./helm \
  --set aim_engine.model_id=meta-llama/Llama-2-70b-chat-hf \
  --set aim_engine.gpu_count=8 \
  --set aim_engine.precision=fp16
```

### **Performance Optimization**
```bash
# Deploy with performance monitoring
helm install aim-engine ./helm \
  --set monitoring.enabled=true \
  --set aim_engine.performance_tuning=true \
  --set aim_engine.vllm_args.max_batch_size=64

# Monitor performance
kubectl port-forward service/prometheus 9090:9090 -n monitoring
# Access Grafana dashboard for performance insights
```

### **Disaster Recovery**
```bash
# Backup recipe configurations
kubectl get configmap -n aim-engine -o yaml > recipe-backup.yaml

# Restore from backup
kubectl apply -f recipe-backup.yaml

# Redeploy with backup configuration
helm upgrade aim-engine ./helm \
  --set aim_engine.restore_from_backup=true
```

## **Recipe Selection Algorithm**

### **Automatic Selection Process**
1. **GPU Detection**: Detect available GPUs in the cluster
2. **Model Analysis**: Analyze model requirements and characteristics
3. **Recipe Filtering**: Filter recipes by model, GPU count, and precision
4. **Performance Ranking**: Rank recipes by expected performance
5. **Resource Validation**: Validate resource requirements against cluster capacity
6. **Fallback Selection**: Select fallback recipe if primary choice unavailable

### **Selection Criteria**
- **GPU Count**: Match available GPUs to model requirements
- **Precision**: Select optimal precision for model size and hardware
- **Performance**: Choose recipe with best expected performance
- **Compatibility**: Ensure recipe compatibility with cluster configuration
- **Resource Efficiency**: Optimize resource utilization

### **Fallback Strategy**
1. **Primary Recipe**: Best performance for given configuration
2. **Secondary Recipe**: Alternative precision or GPU count
3. **Tertiary Recipe**: Minimal viable configuration
4. **Default Recipe**: Generic configuration as last resort

## **Troubleshooting**

### **Common Issues**

#### **Recipe Selection Failures**
```bash
# Check recipe selector logs
kubectl logs job/aim-engine-recipe-selector -n aim-engine

# Verify recipe availability
kubectl get configmap -n aim-engine | grep recipe

# Check GPU availability
kubectl describe node | grep amd.com/gpu
```

#### **Resource Allocation Issues**
```bash
# Check resource requests and limits
kubectl describe pod -n aim-engine deployment/aim-engine

# Verify cluster capacity
kubectl describe node | grep -A 10 "Allocated resources"

# Check GPU operator status
kubectl get pods -n gpu-operator-system
```

#### **Monitoring Issues**
```bash
# Check Prometheus status
kubectl get pods -n monitoring | grep prometheus

# Verify ServiceMonitor
kubectl get servicemonitor -n aim-engine

# Check metrics endpoint
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
curl http://localhost:8000/metrics
```

### **Debug Commands**
```bash
# Enable debug logging
helm upgrade aim-engine ./helm \
  --set aim_engine.debug=true \
  --set aim_engine.log_level=DEBUG

# Check admission controller logs
kubectl logs deployment/aim-engine-recipe-validator -n aim-engine

# Verify webhook configuration
kubectl get validatingwebhookconfiguration | grep aim-engine
```

### **Performance Issues**
```bash
# Check performance metrics
kubectl port-forward service/prometheus 9090:9090 -n monitoring
# Query: aim_performance_tokens_per_second

# Analyze resource utilization
kubectl top pods -n aim-engine
kubectl exec deployment/aim-engine -n aim-engine -- rocm-smi

# Check for bottlenecks
kubectl describe pod -n aim-engine deployment/aim-engine | grep -A 5 "Events"
```

## **File Structure**

```
k8s/
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── recipe-selector-hook.yaml
│       └── ...
├── admission-controller/
│   ├── recipe-validator.yaml
│   └── ...
├── monitoring/
│   ├── recipe-monitoring.yaml
│   ├── recipe-dashboard.yaml
│   └── ...
├── scripts/
│   ├── deploy-with-recipe-support.sh
│   └── ...
└── docs/
    ├── README-RECIPE-FEATURES.md
    └── ...
```

## **Benefits**

### **Performance Optimization**
- **Automatic Optimization**: Recipes automatically optimize for hardware
- **Performance Monitoring**: Real-time performance tracking and alerting
- **Resource Efficiency**: Optimal resource allocation based on recipes

### **Operational Efficiency**
- **Zero Configuration**: Automatic recipe selection reduces manual configuration
- **Consistent Deployments**: Recipe-based configuration ensures consistency
- **Validation**: Admission controllers prevent invalid deployments

### **Resource Management**
- **Dynamic Allocation**: Resources allocated based on recipe requirements
- **Efficient Utilization**: Optimal GPU and memory usage
- **Scalability**: Easy scaling with recipe-aware configurations

### **Monitoring & Observability**
- **Recipe Performance**: Track performance by recipe
- **Resource Monitoring**: Monitor resource utilization
- **Alerting**: Proactive issue detection and alerting

## **Next Steps**

1. **Deploy with Recipe Support**: Use the recipe-aware deployment
2. **Monitor Performance**: Set up monitoring and dashboards
3. **Optimize Recipes**: Create custom recipes for your models
4. **Scale Deployments**: Deploy multiple models with different recipes
5. **Validate Performance**: Use monitoring data to validate recipe performance

The recipe-aware deployment ensures optimal performance and resource utilization for every AIM Engine deployment! 