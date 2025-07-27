# AIM Engine Recipe-Aware Kubernetes Features

## 🎯 **Implemented Features**

This implementation provides **complete recipe-aware Kubernetes deployment** with the following 5 key features:

### **1. ✅ Recipe-Aware Helm Charts with Dynamic Configuration**
- **Dynamic resource allocation** based on recipe selection
- **Automatic command generation** from recipe parameters
- **Environment variable configuration** from recipe settings
- **Support for both auto-selection and manual configuration**

### **2. ✅ Recipe Selection Hooks for Automatic Optimization**
- **Pre-install/pre-upgrade hooks** for recipe selection
- **Automatic fallback strategies** when optimal recipes aren't available
- **Configuration override support** for manual tuning
- **Resource validation** before deployment

### **3. ✅ Recipe Validation in Kubernetes Admission Controllers**
- **Validating webhook** for recipe configuration validation
- **Resource requirement validation** against cluster capacity
- **Recipe compatibility checking** for model/hardware combinations
- **Automatic rejection** of invalid configurations

### **4. ✅ Recipe-Based Monitoring and Alerting**
- **Prometheus metrics** for recipe performance tracking
- **Custom alerts** for recipe-specific issues
- **Resource utilization monitoring** by recipe
- **Performance KPI tracking** with recipe targets

### **5. ✅ Recipe Performance Dashboards**
- **Comprehensive Grafana dashboard** for recipe optimization
- **Real-time performance metrics** by recipe
- **Resource utilization visualization** by GPU count
- **Optimization recommendations** based on metrics

## 🚀 **Quick Start**

### **Deploy with Automatic Recipe Selection**
```bash
# Deploy with automatic recipe selection
./scripts/deploy-with-recipe-support.sh auto localhost:5000 latest

# This will:
# 1. Create namespaces
# 2. Deploy admission controller
# 3. Deploy monitoring
# 4. Deploy AIM Engine with auto-selection
# 5. Verify deployment
# 6. Show recipe information
```

### **Deploy with Configuration Overrides**
```bash
# Deploy with specific overrides
./scripts/deploy-with-recipe-support.sh override localhost:5000 latest

# This will override:
# - GPU count: 4
# - Precision: bf16
# - vLLM args: max_model_len=32768, gpu_memory_utilization=0.9
```

### **Deploy with Specific Recipe**
```bash
# Deploy with manual configuration
./scripts/deploy-with-recipe-support.sh specific localhost:5000 latest

# This will use:
# - GPU count: 2
# - Precision: bf16
# - No auto-selection
```

### **Cleanup**
```bash
# Clean up all deployments
./scripts/deploy-with-recipe-support.sh cleanup
```

## 📊 **Configuration Options**

### **Helm Values Configuration**

#### **Automatic Recipe Selection**
```yaml
aim_engine:
  recipe:
    model_id: "Qwen/Qwen3-32B"
    auto_select: true
    fallback_enabled: true
    constraints:
      max_gpu_count: 8
      min_gpu_count: 1
      preferred_precision: "bf16"
```

#### **Configuration Overrides**
```yaml
aim_engine:
  recipe:
    auto_select: true
    overrides:
      enabled: true
      gpu_count: 4
      precision: "bf16"
      vllm_args:
        max_model_len: 32768
        gpu_memory_utilization: 0.9
      env_vars:
        HIP_VISIBLE_DEVICES: "0,1,2,3"
```

#### **Manual Configuration**
```yaml
aim_engine:
  recipe:
    auto_select: false
    model_id: "Qwen/Qwen3-32B"
  resources:
    gpu_count: 2
  hardware:
    precision: "bf16"
```

## 🔧 **Advanced Usage**

### **Custom Recipe Selection**
```bash
# Deploy with custom recipe parameters
helm install aim-engine ./helm \
  --set aim_engine.recipe.auto_select=true \
  --set aim_engine.recipe.model_id="Qwen/Qwen3-32B" \
  --set aim_engine.recipe.overrides.enabled=true \
  --set aim_engine.recipe.overrides.gpu_count=4 \
  --set aim_engine.recipe.overrides.precision="bf16"
```

### **Monitoring Access**
```bash
# Port forward to access monitoring
kubectl port-forward -n aim-engine-monitoring svc/grafana 3000:3000
kubectl port-forward -n aim-engine-monitoring svc/prometheus 9090:9090

# Access dashboards:
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
```

### **Recipe Validation**
```bash
# Check admission controller status
kubectl get validatingwebhookconfigurations | grep aim-engine

# View validation logs
kubectl logs -n aim-engine deployment/aim-engine-recipe-validator
```

## 📈 **Monitoring Features**

### **Recipe Performance Metrics**
- `aim_recipe_selection_total` - Total recipe selections
- `aim_recipe_fallback_used_total` - Fallback usage count
- `aim_performance_tokens_per_second` - Throughput by recipe
- `aim_gpu_memory_utilization` - GPU utilization by recipe
- `aim_recipe_efficiency_score` - Recipe efficiency score

### **Alerts**
- **Recipe Not Found** - When no suitable recipe is available
- **Recipe Fallback** - When using fallback configuration
- **Low Performance** - When throughput is below targets
- **High Latency** - When latency exceeds thresholds
- **Resource Issues** - When resources are insufficient

### **Dashboard Panels**
1. **Recipe Selection Overview** - Total selections, fallbacks, failures
2. **Performance Throughput** - Tokens/second by recipe and GPU count
3. **GPU Utilization** - Memory and compute utilization by recipe
4. **Latency Performance** - First token and end-to-end latency
5. **Recipe Efficiency** - Efficiency scores and optimization opportunities
6. **Resource Availability** - GPU and memory availability ratios
7. **Performance Comparison** - Side-by-side recipe performance table
8. **Fallback Analysis** - Fallback usage patterns and reasons
9. **Optimization Recommendations** - Actionable optimization suggestions

## 🎯 **Recipe Selection Algorithm**

### **Automatic Selection Process**
1. **Resource Detection** - Detect available GPUs, memory, CPU
2. **Model Analysis** - Determine optimal GPU count based on model size
3. **Precision Selection** - Choose optimal precision (bf16, fp16, fp8)
4. **Recipe Matching** - Find recipes matching requirements
5. **Fallback Strategy** - Try alternative configurations if needed
6. **Validation** - Validate selected recipe against cluster resources

### **Fallback Strategies**
- **GPU Count Fallback** - Try lower GPU counts (8→4→2→1)
- **Precision Fallback** - Try alternative precisions (bf16→fp16→fp8)
- **Backend Fallback** - Try alternative backends (vllm→sglang)

### **Resource Mapping**
| Model Size | Optimal GPUs | Precision | Memory | Batch Tokens |
|------------|--------------|-----------|---------|--------------|
| **7B-8B** | 1 | fp16 | 16Gi | 8,192 |
| **13B-14B** | 2 | bf16 | 32Gi | 16,384 |
| **32B-34B** | 4 | bf16 | 64Gi | 32,768 |
| **70B+** | 8 | bf16 | 128Gi | 65,536 |

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Recipe Selection Fails**
```bash
# Check recipe selector logs
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook

# Check available recipes
kubectl get configmap -n aim-engine aim-engine-recipes -o yaml
```

#### **Admission Controller Issues**
```bash
# Check webhook status
kubectl get validatingwebhookconfigurations aim-engine-recipe-validator

# Check webhook logs
kubectl logs -n aim-engine deployment/aim-engine-recipe-validator
```

#### **Monitoring Issues**
```bash
# Check monitoring components
kubectl get pods -n aim-engine-monitoring

# Check ServiceMonitor
kubectl get servicemonitors -n aim-engine-monitoring
```

### **Debug Commands**
```bash
# Check recipe selection process
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook --tail=50

# Check deployment configuration
kubectl get deployment aim-engine -n aim-engine -o yaml

# Check resource allocation
kubectl describe pod -n aim-engine -l app=aim-engine

# Check monitoring metrics
kubectl port-forward -n aim-engine svc/aim-engine 8000:8000
curl http://localhost:8000/metrics | grep aim_recipe
```

## 📚 **File Structure**

```
k8s/
├── helm/
│   ├── templates/
│   │   ├── deployment.yaml              # Recipe-aware deployment
│   │   ├── recipe-selector-hook.yaml    # Recipe selection hook
│   │   └── ...
│   └── values.yaml                      # Recipe configuration
├── admission-controller/
│   └── recipe-validator.yaml            # Recipe validation webhook
├── monitoring/
│   ├── recipe-monitoring.yaml           # Prometheus monitoring
│   └── recipe-dashboard.yaml            # Grafana dashboard
├── scripts/
│   └── deploy-with-recipe-support.sh    # Deployment script
└── docs/
    ├── recipe-kubernetes-mapping.md     # Detailed mapping guide
    └── recipe-implications-summary.md   # Implementation summary
```

## 🎉 **Benefits**

### **✅ Performance Optimization**
- **Hardware-specific tuning** for AMD GPUs
- **Model-optimized configurations** based on size
- **Automatic resource scaling** based on requirements

### **✅ Operational Efficiency**
- **Consistent deployments** across environments
- **Reduced configuration errors** through validation
- **Automatic fallback strategies** for resource constraints

### **✅ Resource Management**
- **Optimal resource allocation** based on model requirements
- **Efficient GPU utilization** through precision selection
- **Scalable configurations** that grow with hardware

### **✅ Monitoring & Observability**
- **Recipe-aware metrics** for performance tracking
- **Resource utilization monitoring** based on recipe targets
- **Performance KPI tracking** for optimization

## 🚀 **Next Steps**

1. **Deploy the complete solution** using the provided script
2. **Monitor performance** using the Grafana dashboard
3. **Optimize recipes** based on monitoring insights
4. **Scale deployments** using the recipe-aware configurations
5. **Customize monitoring** for your specific requirements

The recipe-aware deployment ensures optimal performance and resource utilization for every AIM Engine deployment! 🎯 