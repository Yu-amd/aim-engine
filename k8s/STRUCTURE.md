# Kubernetes Directory Structure

## 🎯 **Clean Organization**

The `k8s` directory has been reorganized for clarity and ease of use:

```
k8s/
├── README.md                    # Main documentation
├── STRUCTURE.md                 # This file
├── common/                      # Shared resources
│   ├── namespace.yaml          # Namespace definitions
│   ├── configmap.yaml          # Configuration settings
│   └── kustomization.yaml      # Kustomize configuration
├── minikube/                    # Development environment
│   ├── deploy.sh               # Minikube deployment script
│   ├── deployment.yaml         # Minikube deployment (no GPU)
│   ├── service.yaml            # NodePort service
│   ├── storage.yaml            # 10Gi storage
│   ├── rbac.yaml               # Simplified RBAC
│   └── mock-server.py          # Mock API server
├── production/                  # Production environment
│   ├── deploy.sh               # Production deployment script
│   ├── deployment.yaml         # Full GPU deployment
│   ├── service.yaml            # LoadBalancer service
│   ├── storage.yaml            # 500Gi storage
│   ├── rbac.yaml               # Full RBAC with PSP
│   ├── ingress.yaml            # Ingress configuration
│   ├── hpa.yaml                # Horizontal Pod Autoscaler
│   └── monitoring.yaml         # Monitoring setup
├── helm/                        # Helm chart
│   ├── Chart.yaml
│   └── values.yaml
├── patches/                     # Kustomize patches
│   ├── development.yaml
│   └── production.yaml
├── scripts/                     # Helper scripts
│   └── helpers/
│       ├── deploy-minikube.sh
│       └── deploy-production.sh
└── docs/                        # Documentation
    ├── MINIKUBE_TO_PRODUCTION.md
    ├── amd-gpu-setup.md
    
    ├── gpu-comparison.md
    └── README.md
```

## 🚀 **Quick Deployment**

### **Minikube (Development)**
```bash
cd k8s/minikube
./deploy.sh
```

### **Production (AMD GPUs)**
```bash
cd k8s/production
./deploy.sh amd my-registry.com
```



## 📁 **File Organization Benefits**

### **✅ Clear Separation**
- **Minikube**: Development files (no GPU, mock server)
- **Production**: Production files (full GPU, real AIM Engine)
- **Common**: Shared resources (namespace, configmap)

### **✅ Easy Navigation**
- Each environment has its own directory
- Consistent file naming across environments
- Dedicated deployment scripts

### **✅ Simple Migration**
- Clear distinction between environments
- Easy to switch between Minikube and production
- Well-documented migration process

### **✅ Maintainable**
- No duplicate files with different prefixes
- Logical grouping by environment
- Comprehensive documentation

## 🔄 **Migration Path**

### **Minikube → Production**
1. Install GPU device plugin
2. Switch from `minikube/` to `production/` directory
3. Run production deployment script

### **Production → Minikube**
1. Switch from `production/` to `minikube/` directory
2. Run Minikube deployment script

## 📚 **Documentation**

- **[README.md](README.md)** - Main deployment guide
- **[MINIKUBE_TO_PRODUCTION.md](docs/MINIKUBE_TO_PRODUCTION.md)** - Migration guide
- **[GPU Setup Guides](docs/)** - AMD GPU configuration

## 🎉 **Success!**

The `k8s` directory is now clean, organized, and easy to use! 🚀 