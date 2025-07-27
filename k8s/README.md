# AIM Engine Kubernetes Deployment

This directory contains all Kubernetes manifests and deployment scripts for the AIM Engine project, organized by deployment environment.

## 📁 Directory Structure

```
k8s/
├── common/                 # Shared resources for all environments
│   ├── namespace.yaml     # Namespace definitions
│   ├── configmap.yaml     # Configuration settings
│   └── kustomization.yaml # Kustomize configuration
├── minikube/              # Minikube development environment
│   ├── deploy.sh          # Minikube deployment script
│   ├── deployment.yaml    # Minikube-specific deployment
│   ├── service.yaml       # NodePort service
│   ├── storage.yaml       # 10Gi storage
│   ├── rbac.yaml          # Simplified RBAC
│   └── mock-server.py     # Mock API server
├── production/            # Production environment
│   ├── deploy.sh          # Production deployment script
│   ├── deployment.yaml    # Full GPU-enabled deployment
│   ├── service.yaml       # LoadBalancer service
│   ├── storage.yaml       # 500Gi storage
│   ├── rbac.yaml          # Full RBAC with PSP
│   ├── ingress.yaml       # Ingress configuration
│   ├── hpa.yaml           # Horizontal Pod Autoscaler
│   └── monitoring.yaml    # Monitoring setup
├── helm/                  # Helm chart (alternative deployment)
├── patches/               # Kustomize patches
├── scripts/               # Helper scripts
│   └── helpers/           # Deployment helper scripts
└── docs/                  # Documentation
    ├── MINIKUBE_TO_PRODUCTION.md
    ├── amd-gpu-setup.md
    
    └── gpu-comparison.md
```

## 🚀 Quick Start

### **Minikube Development**
```bash
# Deploy to Minikube (development)
cd k8s/minikube
./deploy.sh
```

### **Production Deployment**
```bash
# Deploy to production with AMD GPUs
cd k8s/production
./deploy.sh amd my-registry.com


```

## 🎯 Environment Comparison

| Feature | Minikube | Production |
|---------|----------|------------|
| **GPU Support** | ❌ Mock server | ✅ Full GPU access |
| **Resources** | 2Gi/1 CPU | 32Gi/8 CPU + 4 GPUs |
| **Service** | NodePort | LoadBalancer |
| **Storage** | 10Gi | 500Gi |
| **Use Case** | Development | Production |

## 📋 Prerequisites

### **Minikube**
- Docker
- Minikube
- kubectl

### **Production**
- Kubernetes cluster with GPU nodes
- Docker registry
- kubectl
- AMD GPU device plugin

## 🔧 Configuration

### **Common Configuration**
All environments share these resources:
- **Namespace**: `aim-engine`
- **ConfigMap**: `aim-engine-config`

### **Environment-Specific Configuration**
Each environment has its own:
- **Deployment**: Resource limits, GPU settings
- **Service**: Service type and ports
- **Storage**: Storage class and size
- **RBAC**: Security policies

## 📚 Documentation

- **[Minikube to Production Migration](docs/MINIKUBE_TO_PRODUCTION.md)** - How to migrate between environments
- **[AMD GPU Setup](docs/amd-gpu-setup.md)** - AMD GPU configuration guide

- **[GPU Comparison](docs/gpu-comparison.md)** - GPU support matrix

## 🛠️ Deployment Options

### **1. Minikube (Development)**
```bash
cd k8s/minikube
./deploy.sh
```

### **2. Production (AMD GPUs)**
```bash
cd k8s/production
./deploy.sh amd my-registry.com
```



### **4. Helm Chart**
```bash
cd k8s/helm
helm install aim-engine . --values values.yaml
```

### **5. Kustomize**
```bash
# Development
kubectl apply -k . --env=development

# Production
kubectl apply -k . --env=production
```

## 🔍 Verification

### **Check Deployment Status**
```bash
kubectl get all -n aim-engine
```

### **Check GPU Allocation**
```bash
kubectl describe pod -n aim-engine deployment/aim-engine
```

### **Test Service Access**
```bash
# Minikube
minikube service aim-engine-service -n aim-engine

# Production
kubectl get svc -n aim-engine
```

## 🧹 Cleanup

### **Minikube**
```bash
cd k8s/minikube
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
```

### **Production**
```bash
cd k8s/production
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f ingress.yaml
```

## 📞 Support

For issues and questions:
1. Check the documentation in `docs/`
2. Review deployment logs
3. Verify GPU device plugin installation
4. Check resource allocation

## 🎉 Success!

Your AIM Engine is now deployed and ready to use! 🚀 