# Docker Documentation

This directory contains documentation for **single-node Docker deployments** of AIM Engine.

## Documentation Files

### **DEPLOYMENT.md**
- **Single-node Docker deployment** guide
- **Systemd service configuration** for production
- **Basic and production deployment** examples
- **Hardware and software requirements**

### **AIM_VLLM_USAGE.md**
- **vLLM integration** with AIM Engine
- **Docker command generation** and usage
- **Interactive and server modes**
- **API endpoint testing**

## Quick Start

### **Basic Docker Deployment**
```bash
# Build the container
./scripts/build-aim-vllm.sh

# Run with basic configuration
docker run -d \
  --name aim-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  aim-vllm:latest \
  aim-generate Qwen/Qwen3-32B
```

### **Production Deployment**
See `DEPLOYMENT.md` for complete production setup with systemd services.

## Related Files

- **`../Dockerfile.aim-vllm`** - Main Docker image for vLLM
- **`../Dockerfile.aim-tgi`** - Docker image for TGI (Text Generation Inference)
- **`../../scripts/build-aim-vllm.sh`** - Build script

## Notes

- This documentation is for **single-node Docker deployments**
- For **Kubernetes deployments**, see `../../k8s/docs/`
- For **general project documentation**, see `../../docs/` 