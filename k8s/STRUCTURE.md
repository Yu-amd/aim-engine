# AIM Engine Kubernetes Directory Structure

This directory contains production-ready Kubernetes deployment configurations for AIM Engine.

```
k8s/
├── helm/                   # Helm chart for production deployment
│   ├── Chart.yaml         # Helm chart metadata
│   ├── values.yaml        # Default configuration values
│   └── templates/         # Kubernetes resource templates
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── pvc.yaml
│       ├── serviceaccount.yaml
│       └── _helpers.tpl
├── scripts/               # Deployment and management scripts
│   ├── setup-complete-kubernetes.sh    # Complete cluster setup
│   ├── deploy-aim-engine.sh            # Production deployment
│   ├── cleanup-kubernetes.sh           # Cleanup utilities
│   └── helpers/                        # Helper scripts
├── docs/                  # Documentation
│   ├── README.md          # Main documentation
│   ├── PRODUCTION.md      # Production deployment guide
│   ├── amd-gpu-setup.md   # AMD GPU configuration
│   └── recipe-kubernetes-mapping.md
├── production/            # Production-specific configurations
├── monitoring/            # Monitoring and observability
├── admission-controller/  # Kubernetes admission controllers
├── common/                # Shared configurations
├── patches/               # Kustomize patches
├── KUBERNETES_DEPLOYMENT.md  # Main deployment guide
├── README.md              # Quick start guide
└── STRUCTURE.md           # This file
```

## **Deployment Options**

### **Production (Helm)**

The recommended approach for production deployments:

```bash
# Complete setup (fresh node)
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Deploy to existing cluster
sudo ./k8s/scripts/deploy-aim-engine.sh
```

**Features:**
- **Production-ready**: Optimized for real workloads
- **GPU support**: Full AMD GPU integration
- **Scalability**: Multi-node cluster support
- **Monitoring**: Built-in observability
- **Security**: RBAC and network policies

## **Quick Start**

### **1. Choose Your Approach**

- **Complete Setup**: Fresh node with full cluster setup
- **Existing Cluster**: Deploy to existing Kubernetes cluster

### **2. Deploy AIM Engine**

```bash
# Complete setup
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Or deploy to existing cluster
sudo ./k8s/scripts/deploy-aim-engine.sh
```

### **3. Verify Deployment**

```bash
# Check status
kubectl get pods -n aim-engine

# Test endpoint
curl http://localhost:<NODEPORT>/health
```

## **Configuration**

### **Environment-Specific Configurations**

- **Production**: Optimized for real workloads with GPU support
- **Custom**: Tailored configurations for specific requirements

### **Resource Management**

- **GPU allocation**: Automatic or manual GPU assignment
- **Memory limits**: Model-specific memory requirements
- **CPU allocation**: Optimized for inference workloads

## **Documentation**

- **[Kubernetes Deployment Guide](KUBERNETES_DEPLOYMENT.md)** - Complete production deployment
- **[Production Guide](docs/PRODUCTION.md)** - Production best practices
- **[AMD GPU Setup](docs/amd-gpu-setup.md)** - GPU configuration
- **[Recipe System](docs/recipe-kubernetes-mapping.md)** - Recipe integration

## **Scripts Overview**

### **Setup Scripts**

- **`setup-complete-kubernetes.sh`**: Complete cluster setup with AMD GPU support
- **`deploy-aim-engine.sh`**: Deploy to existing cluster with flexible configuration

### **Management Scripts**

- **`cleanup-kubernetes.sh`**: Comprehensive cleanup utilities
- **Helper scripts**: Additional utilities for specific tasks
