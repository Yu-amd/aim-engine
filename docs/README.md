# AIM Engine Documentation

This directory contains the main documentation for the AIM Engine project.

## Documentation Structure

### **Core Documentation**
- **`README.md`** - Main documentation overview
- **`ARCHITECTURE.md`** - System architecture and design
- **`API.md`** - API reference and usage
- **`RECIPE_GUIDE.md`** - Recipe system documentation
- **`TROUBLESHOOTING.md`** - Common issues and solutions

### **Technical Documentation**
- **`AIM_ENGINE_OVERVIEW.md`** - High-level project overview
- **`AIM_ENGINE_DETAIL.md`** - Detailed technical specifications
- **`AIM_Engine_BOM.md`** - Bill of Materials and dependencies
- **`architecture-diagrams.md`** - Visual architecture diagrams

### **Deployment Documentation**
- **`docker/docs/`** - Single-node Docker deployment guides
- **`k8s/docs/`** - Kubernetes deployment guides

## Quick Navigation

### **For Docker Deployments**
- **Single-node Docker**: See `../docker/docs/DEPLOYMENT.md`
- **vLLM Integration**: See `../docker/docs/AIM_VLLM_USAGE.md`

### **For Kubernetes Deployments**
- **Development (Minikube)**: See `../k8s/docs/DEVELOPMENT.md`
- **Production (Helm)**: See `../k8s/docs/PRODUCTION.md`
- **Quick Start**: See `../k8s/docs/README.md`

### **For Development**
- **Architecture**: See `ARCHITECTURE.md`
- **API Reference**: See `API.md`
- **Recipe System**: See `RECIPE_GUIDE.md`
- **Troubleshooting**: See `TROUBLESHOOTING.md`

## Project Structure

```
aim-engine/
├── docs/                   # General documentation (this directory)
├── docker/
│   ├── docs/              # Docker deployment documentation
│   ├── Dockerfile.aim-vllm
│   └── Dockerfile.aim-tgi
├── k8s/
│   └── docs/              # Kubernetes deployment documentation
├── src/aim_engine/        # Core Python package
├── config/                # Configuration files
├── scripts/               # Build and deployment scripts
└── examples/              # Usage examples
```

## Getting Started

1. **Choose your deployment method**:
   - **Docker**: For single-node deployments
   - **Kubernetes**: For cluster deployments

2. **Read the appropriate documentation**:
   - Docker: `../docker/docs/`
   - Kubernetes: `../k8s/docs/`

3. **For development**: Start with `ARCHITECTURE.md` and `API.md`
