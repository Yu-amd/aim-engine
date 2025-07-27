# AIM Engine Kubernetes Directory Structure

## **Clean Organization**

The `k8s` directory has been reorganized for clarity and maintainability. Here's the new structure:

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
│   └── monitoring.yaml    # Basic monitoring
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
│   ├── Chart.yaml         # Helm chart definition
│   ├── values.yaml        # Default values
│   └── templates/         # Helm templates
├── patches/               # Kustomize patches
│   ├── development.yaml   # Development overrides
│   └── production.yaml    # Production overrides
├── scripts/               # Helper scripts
│   └── helpers/           # Deployment helper scripts
└── docs/                  # Documentation
    ├── README.md          # Main documentation
    ├── DEVELOPMENT.md     # Development guide
    ├── PRODUCTION.md      # Production guide
    └── amd-gpu-setup.md   # AMD GPU setup
```

## **Quick Deployment**

### **Minikube (Development)**
```bash
cd k8s/minikube
./deploy.sh
```

### **Production (Full Kubernetes)**
```bash
cd k8s/production
./deploy.sh
```

### **Helm Chart**
```bash
cd k8s/helm
helm install aim-engine . --values values.yaml
```

### **Kustomize**
```bash
# Development
kubectl apply -k ./common --env=development

# Production
kubectl apply -k ./common --env=production
```

## **Benefits**

### **Clear Separation**
- **Development**: Minikube-specific configurations
- **Production**: Full Kubernetes configurations
- **Shared**: Common resources used by both

### **Easy Navigation**
- **Logical grouping**: Related files are together
- **Clear naming**: Files indicate their purpose
- **Consistent structure**: Same pattern across environments

### **Simple Migration**
- **Development to Production**: Clear migration path
- **Environment-specific**: Each environment has its own directory
- **Shared resources**: Common configurations are reusable

### **Maintainable**
- **Modular design**: Easy to modify individual components
- **Version control**: Clear change tracking
- **Documentation**: Each directory has its own documentation

## **Migration Path**

### **From Old Structure**
1. **Backup**: Save your current configurations
2. **Choose Environment**: Select minikube or production
3. **Deploy**: Use the new deployment scripts
4. **Verify**: Test the deployment
5. **Cleanup**: Remove old configurations

### **Environment Migration**
1. **Development**: Start with minikube for testing
2. **Staging**: Use production configs with limited resources
3. **Production**: Full deployment with monitoring

## **Documentation**

- **README.md**: Main documentation and quick start
- **DEVELOPMENT.md**: Detailed development guide
- **PRODUCTION.md**: Detailed production guide
- **amd-gpu-setup.md**: AMD GPU configuration

## **Success!**

The `k8s` directory is now clean, organized, and easy to use! 