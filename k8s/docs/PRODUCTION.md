# AIM Engine Production Guide - Helm Deployment

## **Overview**

This comprehensive guide provides everything you need to deploy AIM Engine to production using Helm charts. This approach is designed for production workloads with AMD GPU support, comprehensive monitoring, and enterprise-grade features.

## **Features**

### **Recipe Selection**
- **Automatic recipe selection** based on available GPUs and model requirements
- **Configuration overrides** for custom deployments
- **Fallback mechanisms** for optimal performance
- **Recipe validation** through admission controllers

### **Monitoring & Observability**
- **Prometheus metrics** collection and alerting
- **Grafana dashboards** for performance visualization
- **Custom alerts** for recipe-specific issues
- **Performance optimization** recommendations

### **Production Features**
- **AMD GPU support** with ROCm
- **High availability** with multiple replicas
- **Auto-scaling** based on demand
- **Security** with RBAC and admission controllers
- **Enterprise-grade** monitoring and logging

## **Prerequisites**

### **Cluster Requirements**
- Kubernetes cluster (1.20+)
- AMD GPU nodes with ROCm support
- AMD GPU device plugin installed
- Helm 3.x installed
- kubectl configured
- Container registry access

### **Hardware Requirements**
- AMD GPU nodes (MI300X recommended)
- Sufficient CPU and memory for model loading
- Fast storage for model cache
- Network connectivity for model downloads

### **Software Requirements**
```bash
# Check kubectl
kubectl version --client

# Check helm
helm version

# Check cluster connectivity
kubectl cluster-info

# Check GPU nodes
kubectl get nodes -l amd.com/gpu=true
```

## **Deployment Methods**

### **Method 1: Script-Based Deployment (Recommended)**
**Use Case**: Full automation with monitoring and validation
**Complexity**: Advanced
**Features**: Complete recipe support, monitoring, admission controllers

### **Method 2: Helm Chart Deployment**
**Use Case**: Standard Helm-based deployment
**Complexity**: Medium
**Features**: Recipe support, basic monitoring

### **Method 3: Advanced Configuration with Overrides**
**Use Case**: Custom configurations with specific requirements
**Complexity**: Advanced
**Features**: Full customization, overrides support

## **Quick Start**

### **Step 1: Prepare Cluster**
```bash
# Install AMD GPU device plugin
kubectl create -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Verify GPU detection
kubectl get nodes -l amd.com/gpu=true
kubectl get nodes -o json | jq '.items[0].status.allocatable."amd.com/gpu"'
```

### **Step 2: Build and Push Docker Image**
```bash
# Build AIM Engine image
docker build -f Dockerfile.aim-vllm -t aim-vllm:latest .

# Tag for registry
docker tag aim-vllm:latest your-registry.com/aim-vllm:latest

# Push to registry
docker push your-registry.com/aim-vllm:latest
```

### **Step 3: Deploy with Recipe Support**

#### **Method 1A: Script-Based Deployment**
```bash
# Navigate to k8s directory
cd k8s

# Deploy with automatic recipe selection
./scripts/deploy-with-recipe-support.sh auto your-registry.com latest
```

#### **Method 1B: Helm Chart Deployment**
```bash
# Deploy with Helm
helm install aim-engine ./helm \
  --namespace aim-engine \
  --create-namespace \
  --set image.repository=your-registry.com/aim-vllm \
  --set image.tag=latest \
  --set aim_engine.recipe.auto_select=true \
  --set aim_engine.recipe.model_id="Qwen/Qwen3-32B"
```

#### **Method 1C: Advanced Configuration with Overrides**
```bash
# Deploy with custom configuration overrides
./scripts/deploy-with-recipe-support.sh override your-registry.com latest

# Or use custom values file
helm install aim-engine ./helm \
  --namespace aim-engine \
  --create-namespace \
  --values custom-values.yaml
```

## **Configuration Options**

### **Recipe Configuration**

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
        max_num_batched_tokens: 32768
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

### **Resource Configuration**

#### **GPU Resource Mapping**
```yaml
resources:
  requests:
    amd.com/gpu: "4"    # Maps to recipe GPU count
    memory: "64Gi"      # Scales with GPU count
    cpu: "16"           # Scales with GPU count
  limits:
    amd.com/gpu: "4"
    memory: "128Gi"
    cpu: "32"
```

#### **Scaling Configuration**
```yaml
replicaCount:
  development: 1
  production: 2

hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### **Security Configuration**

#### **RBAC Setup**
```yaml
rbac:
  create: true
  clusterRole:
    create: true
    rules:
      - apiGroups: [""]
        resources: ["pods", "services", "endpoints"]
        verbs: ["get", "list", "watch"]
```

#### **Pod Security**
```yaml
podSecurityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 0

securityContext:
  privileged: true
  allowPrivilegeEscalation: true
  capabilities:
    add:
      - SYS_ADMIN
```

## **Monitoring Setup**

### **Prometheus Integration**

#### **ServiceMonitor Configuration**
```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
    honorLabels: true
```

#### **Custom Metrics**
```yaml
# AIM Engine exposes custom metrics
# aim_recipe_selection_total{recipe_id="qwen3-32b-4gpu-bf16"} 1
# aim_performance_tokens_per_second{recipe_id="qwen3-32b-4gpu-bf16"} 150
# aim_gpu_memory_utilization{recipe_id="qwen3-32b-4gpu-bf16"} 0.85
```

### **Grafana Dashboards**

#### **Recipe Performance Dashboard**
- **Recipe selection overview**
- **Performance metrics by recipe**
- **GPU utilization tracking**
- **Resource efficiency analysis**

#### **Alerting Rules**
```yaml
prometheusRule:
  enabled: true
  groups:
    - name: aim-engine.rules
      rules:
        - alert: AIMEngineRecipeNotFound
          expr: aim_recipe_selection_total == 0
          for: 5m
          labels:
            severity: critical
        - alert: AIMEngineLowThroughput
          expr: aim_performance_tokens_per_second < 100
          for: 10m
          labels:
            severity: warning
```

## **Verification Steps**

### **Step 1: Check Deployment Status**
```bash
# Check all pods
kubectl get pods -n aim-engine

# Expected output:
NAME                           READY   STATUS    RESTARTS   AGE
aim-engine-6d4cf56db-abc12    1/1     Running   0          2m
aim-engine-6d4cf56db-def34    1/1     Running   0          2m

# Check deployments
kubectl get deployment -n aim-engine

# Expected output:
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
aim-engine   2/2     2            2           2m
```

### **Step 2: Verify Recipe Selection**
```bash
# Check recipe selector job
kubectl get jobs -n aim-engine

# Expected output:
NAME                           COMPLETIONS   DURATION   AGE
aim-engine-recipe-selector     1/1           30s        2m

# Check recipe selection logs
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook

# Expected output:
Recipe Selection Configuration:
  Model ID: Qwen/Qwen3-32B
  GPU Count: 4
  Precision: bf16
  Backend: vllm
Selected Recipe: qwen3-32b-4gpu-bf16
Configuration: 4 GPUs, bf16 precision
```

### **Step 3: Verify GPU Allocation**
```bash
# Check GPU allocation
kubectl describe pod -n aim-engine -l app=aim-engine | grep -A 10 "Containers:"

# Expected output:
Containers:
  aim-engine:
    Limits:
      amd.com/gpu:     4
      cpu:             32
      memory:          128Gi
    Requests:
      amd.com/gpu:     4
      cpu:             16
      memory:          64Gi

# Test GPU access
kubectl exec -it -n aim-engine deployment/aim-engine -- rocm-smi

# Expected output:
===================== ROCm System Management Interface =====================
================================= Concise Info =================================
GPU  Temp   AvgPwr  SCLK     MCLK     Fan     Perf  PwrCap  VRAM%  GPU%
0    45.0c  45.0W   800Mhz   1600Mhz  0%      auto  300.0W   0%    0%
1    45.0c  45.0W   800Mhz   1600Mhz  0%      auto  300.0W   0%    0%
2    45.0c  45.0W   800Mhz   1600Mhz  0%      auto  300.0W   0%    0%
3    45.0c  45.0W   800Mhz   1600Mhz  0%      auto  300.0W   0%    0%
```

### **Step 4: Verify Service Access**
```bash
# Check services
kubectl get svc -n aim-engine

# Expected output:
NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
aim-engine-service    LoadBalancer   10.96.123.45    192.168.1.100   80:30080/TCP     2m

# Test service endpoints
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine

# Test health endpoint
curl http://localhost:8000/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "recipe_id": "qwen3-32b-4gpu-bf16"
}

# Test recipe endpoint
curl http://localhost:8000/recipe

# Expected response:
{
  "recipe_id": "qwen3-32b-4gpu-bf16",
  "model_id": "Qwen/Qwen3-32B",
  "gpu_count": 4,
  "precision": "bf16",
  "backend": "vllm",
  "hardware": {
    "type": "MI300X",
    "rocm_arch": "gfx90a"
  },
  "performance": {
    "expected_tokens_per_second": 150,
    "expected_latency_ms": 100
  }
}
```

### **Step 5: Verify Monitoring**
```bash
# Check monitoring pods
kubectl get pods -n aim-engine-monitoring

# Expected output:
NAME                           READY   STATUS    RESTARTS   AGE
prometheus-6d4cf56db-abc12    1/1     Running   0          2m
grafana-6d4cf56db-def34       1/1     Running   0          2m

# Check ServiceMonitor
kubectl get servicemonitor -n aim-engine-monitoring

# Expected output:
NAME                    AGE
aim-engine-monitoring   2m

# Check Prometheus rules
kubectl get prometheusrule -n aim-engine-monitoring

# Expected output:
NAME                    AGE
aim-engine-alerts       2m

# Access Grafana
kubectl port-forward -n aim-engine-monitoring svc/grafana 3000:3000

# Access Prometheus
kubectl port-forward -n aim-engine-monitoring svc/prometheus 9090:9090
```

## **Troubleshooting**

### **Common Issues**

#### **GPU Not Available**
```bash
# Check GPU device plugin
kubectl get pods -n kube-system | grep amd-device-plugin

# Expected output:
amd-device-plugin-ds-abc12    1/1     Running   0          10m

# Check GPU nodes
kubectl get nodes -l amd.com/gpu=true

# Expected output:
NAME       STATUS   ROLES    AGE   VERSION
gpu-node1  Ready    worker   10m   v1.25.0
gpu-node2  Ready    worker   10m   v1.25.0

# Check GPU allocation
kubectl describe nodes | grep -A 10 "amd.com/gpu"

# Expected output:
amd.com/gpu:    8
```

#### **Recipe Selection Fails**
```bash
# Check recipe selector logs
kubectl logs -n aim-engine job/aim-engine-recipe-selector-hook

# Common issues:
# - No suitable recipe found: Check available recipes
# - Resource constraints: Increase cluster resources
# - Configuration errors: Check recipe format

# Check available recipes
kubectl get configmap -n aim-engine aim-engine-recipes -o yaml

# Check recipe configuration
kubectl get configmap -n aim-engine aim-engine-recipe-config -o yaml
```

#### **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n aim-engine

# Expected output:
NAME                  ENDPOINTS                                 AGE
aim-engine-service    10.244.1.10:8000,10.244.2.10:8000        2m

# Check service configuration
kubectl describe svc -n aim-engine aim-engine-service

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://aim-engine-service:8000/health

# Check ingress (if configured)
kubectl get ingress -n aim-engine
kubectl describe ingress -n aim-engine aim-engine-ingress
```

#### **Monitoring Not Working**
```bash
# Check monitoring pods
kubectl get pods -n aim-engine-monitoring

# Check ServiceMonitor
kubectl get servicemonitor -n aim-engine-monitoring

# Check Prometheus rules
kubectl get prometheusrule -n aim-engine-monitoring

# Test metrics endpoint
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
curl http://localhost:8000/metrics | grep aim_recipe

# Expected output:
# aim_recipe_selection_total{recipe_id="qwen3-32b-4gpu-bf16"} 1
# aim_performance_tokens_per_second{recipe_id="qwen3-32b-4gpu-bf16"} 150
```

### **Debug Commands**

#### **Resource Usage**
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n aim-engine

# Check resource requests/limits
kubectl describe pod -n aim-engine -l app=aim-engine | grep -A 10 "Containers:"
```

#### **Network Issues**
```bash
# Check DNS resolution
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup aim-engine-service

# Check network policies
kubectl get networkpolicy -n aim-engine

# Test connectivity
kubectl run test-connectivity --image=busybox --rm -it --restart=Never -- wget -O- http://aim-engine-service:8000/health
```

#### **Storage Issues**
```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc -n aim-engine

# Check storage class
kubectl get storageclass
```

### **Performance Issues**

#### **Low Throughput**
```bash
# Check GPU utilization
kubectl exec -it -n aim-engine deployment/aim-engine -- rocm-smi

# Check performance metrics
kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine
curl http://localhost:8000/metrics | grep performance

# Check resource pressure
kubectl describe nodes | grep -A 5 "Conditions:"
```

#### **High Latency**
```bash
# Check model loading
kubectl logs -n aim-engine deployment/aim-engine | grep -E "(load|model)"

# Check batch processing
kubectl logs -n aim-engine deployment/aim-engine | grep -E "(batch|token)"

# Check memory usage
kubectl top pods -n aim-engine
```

## **Best Practices**

### **Resource Management**
- **Right-size resources** based on model requirements
- **Use resource requests and limits** to prevent resource starvation
- **Monitor resource usage** and adjust as needed
- **Plan for scaling** with horizontal pod autoscaler

### **Security**
- **Use RBAC** to limit pod permissions
- **Enable admission controllers** for recipe validation
- **Use network policies** to restrict traffic
- **Regular security updates** for base images

### **Monitoring**
- **Set up comprehensive monitoring** with Prometheus/Grafana
- **Configure meaningful alerts** for critical issues
- **Monitor recipe performance** and optimization opportunities
- **Track resource utilization** and efficiency

### **Performance**
- **Choose optimal recipes** for your hardware
- **Monitor GPU utilization** and adjust batch sizes
- **Use appropriate precision** for your use case
- **Optimize model loading** and caching

## **Advanced Configuration**

### **Custom Recipe Configuration**
```yaml
# Create custom recipe
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-recipe
data:
  custom-recipe.yaml: |
    recipe_id: custom-32b-4gpu-bf16
    model_id: "Qwen/Qwen3-32B"
    gpu_count: 4
    precision: bf16
    backend: vllm
    hardware:
      type: MI300X
      rocm_arch: gfx90a
    config:
      args:
        max_model_len: 32768
        gpu_memory_utilization: 0.9
        max_num_batched_tokens: 32768
    performance:
      expected_tokens_per_second: 150
      expected_latency_ms: 100
    resources:
      requests:
        memory: "64Gi"
        cpu: "16"
      limits:
        memory: "128Gi"
        cpu: "32"
```

### **Multi-Model Deployment**
```yaml
# Deploy multiple models
helm install aim-engine-7b ./helm \
  --namespace aim-engine \
  --set aim_engine.recipe.model_id="Qwen/Qwen2-7B" \
  --set aim_engine.resources.gpu_count=1

helm install aim-engine-32b ./helm \
  --namespace aim-engine \
  --set aim_engine.recipe.model_id="Qwen/Qwen3-32B" \
  --set aim_engine.resources.gpu_count=4
```

### **High Availability Setup**
```yaml
# Configure high availability
replicaCount:
  production: 3

podDisruptionBudget:
  enabled: true
  minAvailable: 2

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - aim-engine
        topologyKey: kubernetes.io/hostname
```

## **Production Checklist**

### **Pre-Deployment**
- [ ] **Cluster preparation** - AMD GPU nodes configured
- [ ] **GPU device plugin** - AMD GPU device plugin installed
- [ ] **Storage setup** - Fast storage for model cache
- [ ] **Network configuration** - Load balancer and ingress configured
- [ ] **Security setup** - RBAC and admission controllers configured

### **Deployment**
- [ ] **Image building** - AIM Engine image built and pushed
- [ ] **Recipe selection** - Optimal recipe selected for hardware
- [ ] **Resource allocation** - GPU and memory resources allocated
- [ ] **Service deployment** - Load balancer service deployed
- [ ] **Monitoring setup** - Prometheus and Grafana configured

### **Post-Deployment**
- [ ] **Health verification** - All pods running and healthy
- [ ] **GPU verification** - GPU resources allocated correctly
- [ ] **Service verification** - Service accessible and responding
- [ ] **Performance testing** - Throughput and latency meet requirements
- [ ] **Monitoring verification** - Metrics collection and alerting working

### **Ongoing Operations**
- [ ] **Regular monitoring** - Performance and resource usage
- [ ] **Alert management** - Respond to and resolve alerts
- [ ] **Performance optimization** - Tune recipes and configurations
- [ ] **Security updates** - Regular security patches and updates
- [ ] **Capacity planning** - Monitor and plan for scaling needs

## **Next Steps**

### **Scaling and Optimization**
- **Horizontal scaling** with HPA based on demand
- **Vertical scaling** by adjusting resource requests
- **Recipe optimization** for better performance
- **Model optimization** for efficiency

### **Advanced Features**
- **Multi-model support** for different use cases
- **A/B testing** with different recipes
- **Canary deployments** for safe updates
- **Blue-green deployments** for zero downtime

### **Integration**
- **API gateway** for request routing
- **Load balancing** across multiple instances
- **Caching layer** for improved performance
- **Log aggregation** for centralized logging

This comprehensive production guide ensures a **complete, enterprise-ready deployment** of AIM Engine with full monitoring, scaling, and operational capabilities! 