# AIM Engine Troubleshooting Guide

## Overview

This guide provides solutions for common issues encountered when deploying and using the AIM (AMD Inference Microservice) Engine. Each section includes diagnostic steps, root causes, and solutions.

## Quick Diagnostic Commands

### System Health Check

```bash
# Check GPU status
rocm-smi

# Check Docker status
docker ps
docker system df

# Check system resources
htop
df -h
free -h

# Check network connectivity
curl -v http://localhost:8000/health
netstat -tlnp | grep 8000
```

### AIM Engine Status

```bash
# Check AIM Engine processes
ps aux | grep aim-engine

# Check container logs
docker logs <container-name>

# Check cache status
aim-engine cache stats

# Check GPU detection
aim-engine debug gpu-info
```

## GPU Detection Issues

### Problem: GPU Not Detected

**Symptoms**:
- Error: `No GPUs detected`
- Error: `RuntimeError: please set tensor_parallel_size (8) to less than max local gpu count (1)`
- AIM Engine reports 0 or 1 GPU when more are available

**Diagnostic Steps**:

```bash
# 1. Check host GPU detection
rocm-smi
rocm-smi  # if using AMD GPUs

# 2. Check container GPU access
docker run --rm --device=/dev/kfd rocm/vllm:latest rocm-smi

# 3. Check PyTorch GPU detection
docker run --rm --device=/dev/kfd rocm/vllm:latest python -c "import torch; print(torch.cuda.device_count())"

# 4. Check GPU device files
ls -la /dev/kfd
ls -la /dev/dri
```

**Root Causes**:
1. ROCm drivers not properly installed
2. Docker GPU access not configured
3. GPU device files missing or inaccessible
4. Container running without proper GPU flags

**Solutions**:

1. **Install/Update ROCm Drivers**:
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install rocm-dkms

   # RHEL/CentOS
   sudo yum install rocm-dkms
   ```

2. **Configure Docker GPU Access**:
   ```bash
   # Add user to video group
   sudo usermod -a -G video $USER

   # Restart Docker
   sudo systemctl restart docker

   # Test GPU access
   docker run --rm --device=/dev/kfd --device=/dev/dri --group-add=video rocm/vllm:latest rocm-smi
   ```

3. **Use Correct Docker Flags**:
   ```bash
   docker run --rm \
     --device=/dev/kfd \
     --device=/dev/dri \
     --group-add=video \
     --cap-add=SYS_RAWIO \
     aim-engine:latest \
     aim-engine launch Model/Name 8
   ```

### Problem: GPU Count Mismatch

**Symptoms**:
- Host shows 8 GPUs, container shows 1 GPU
- vLLM reports different GPU count than expected
- Tensor parallelism errors

**Diagnostic Steps**:

```bash
# 1. Check different detection methods
echo "Host GPUs:"
rocm-smi | grep -c "GPU"

echo "Container GPUs:"
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add=video rocm/vllm:latest rocm-smi | grep -c "GPU"

echo "PyTorch GPUs:"
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add=video rocm/vllm:latest python -c "import torch; print(torch.cuda.device_count())"
```

**Solutions**:

1. **Force GPU Count**:
   ```bash
   # Specify exact GPU count
   aim-engine launch Model/Name 4  # Use actual available count
   ```

2. **Check GPU Visibility**:
   ```bash
   # Run with explicit GPU mapping
   docker run --rm \
     --device=/dev/kfd \
     --device=/dev/dri \
     --group-add=video \
     --cap-add=SYS_RAWIO \
     --gpus all \
     aim-engine:latest \
     aim-engine launch Model/Name 8
   ```

## Memory Issues

### Problem: Out of Memory (OOM)

**Symptoms**:
- Error: `CUDA out of memory`
- Container crashes during model loading
- GPU memory utilization at 100%

**Diagnostic Steps**:

```bash
# 1. Check GPU memory
rocm-smi --showproductname --showmeminfo

# 2. Check system memory
free -h

# 3. Check container memory usage
docker stats

# 4. Check model size
du -sh /workspace/model-cache/*
```

**Solutions**:

1. **Reduce GPU Memory Utilization**:
   ```bash
   # Use lower memory utilization
   aim-engine launch Model/Name 8 --precision fp16
   
   # Or modify recipe to use lower utilization
   --gpu-memory-utilization: "0.8"  # Instead of 0.9
   ```

2. **Use Smaller Model or Precision**:
   ```bash
   # Try smaller model
   aim-engine launch Qwen/Qwen2-7B 4
   
   # Try different precision
   aim-engine launch Model/Name 8 --precision fp16
   ```

3. **Increase System Memory**:
   ```bash
   # Add swap space
   sudo fallocate -l 64G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

### Problem: Model Loading Timeout

**Symptoms**:
- Model takes too long to load
- Timeout errors during startup
- Endpoint never becomes ready

**Diagnostic Steps**:

```bash
# 1. Check model download progress
docker logs <container-name> | grep -i "download"

# 2. Check network speed
curl -o /dev/null -s -w "%{speed_download}\n" https://huggingface.co/Model/Name

# 3. Check disk I/O
iostat -x 1

# 4. Check cache status
aim-engine cache stats
```

**Solutions**:

1. **Increase Timeout**:
   ```bash
   # Set longer timeout
   export AIM_TIMEOUT=1200  # 20 minutes
   aim-engine launch Model/Name 8
   ```

2. **Pre-download Models**:
   ```bash
   # Download model to cache first
   aim-engine cache download Model/Name
   
   # Then launch with cache
   aim-engine launch Model/Name 8 --use-cache
   ```

## Network and Connectivity Issues

### Problem: Port Already in Use

**Symptoms**:
- Error: `Address already in use`
- Cannot bind to port 8000
- Service fails to start

**Diagnostic Steps**:

```bash
# 1. Check port usage
netstat -tlnp | grep 8000
lsof -i :8000

# 2. Check Docker containers
docker ps | grep 8000

# 3. Check system services
sudo systemctl status aim-engine
```

**Solutions**:

1. **Stop Conflicting Services**:
   ```bash
   # Stop conflicting container
   docker stop <container-name>
   
   # Stop system service
   sudo systemctl stop aim-engine
   ```

2. **Use Different Port**:
   ```bash
   # Launch on different port
   aim-engine launch Model/Name 8 --port 8001
   
   # Or modify Docker run command
   docker run -p 8001:8000 aim-engine:latest aim-engine launch Model/Name 8
   ```

### Problem: Endpoint Not Accessible

**Symptoms**:
- `curl: (7) Failed to connect to localhost port 8000`
- Endpoint health check fails
- Service appears running but not responding

**Diagnostic Steps**:

```bash
# 1. Check container status
docker ps | grep aim-engine

# 2. Check container logs
docker logs <container-name>

# 3. Check endpoint health
curl -v http://localhost:8000/health

# 4. Check port mapping
docker port <container-name>
```

**Solutions**:

1. **Check Port Mapping**:
   ```bash
   # Ensure port is properly mapped
   docker run -p 8000:8000 aim-engine:latest aim-engine launch Model/Name 8
   ```

2. **Wait for Endpoint Ready**:
   ```bash
   # Check if endpoint is still starting
   docker logs <container-name> | grep -i "ready"
   
   # Wait for health check
   while ! curl -s http://localhost:8000/health; do
     echo "Waiting for endpoint..."
     sleep 10
   done
   ```

## Recipe and Configuration Issues

### Problem: Invalid Recipe Configuration

**Symptoms**:
- Error: `No suitable configuration found for Model/Name`
- Warning: `Skipping invalid argument for vllm`
- Recipe validation fails

**Diagnostic Steps**:

```bash
# 1. Validate recipe
python3 src/aim/validate_aim_recipe_yaml.py recipes/your-recipe.yaml

# 2. Check recipe syntax
yamllint recipes/your-recipe.yaml

# 3. Check available recipes
aim-engine list recipes

# 4. Check model compatibility
aim-engine show-config Model/Name
```

**Solutions**:

1. **Fix Recipe Syntax**:
   ```yaml
   # Correct vLLM arguments
   args:
     --model: "Model/Name"
     --dtype: "bfloat16"
     --max-model-len: "32768"  # Correct argument name
     --gpu-memory-utilization: "0.9"
   ```

2. **Update Outdated Arguments**:
   ```yaml
   # Remove deprecated arguments
   # --max-batch-size: "8"        # Remove this
   # --max-context-len: "32768"   # Remove this
   
   # Use correct arguments
   --max-model-len: "32768"       # Use this instead
   ```

### Problem: GPU Count Not Supported

**Symptoms**:
- Error: `GPU count 9 not supported in recipe`
- No recipe found for requested GPU count
- Fallback to 1 GPU when more available

**Solutions**:

1. **Use Supported GPU Count**:
   ```bash
   # Use supported GPU count (1, 2, 4, 8)
   aim-engine launch Model/Name 4  # Instead of 9
   ```

2. **Let AIM Engine Auto-Select**:
   ```bash
   # Don't specify GPU count, let AIM Engine choose
   aim-engine launch Model/Name
   ```

## Performance Issues

### Problem: Slow Inference

**Symptoms**:
- Low tokens per second
- High latency
- GPU utilization below expected

**Diagnostic Steps**:

```bash
# 1. Check GPU utilization
rocm-smi -d 0 --showutilization

# 2. Check memory usage
rocm-smi --showproductname --showmeminfo

# 3. Check temperature
rocm-smi --showtemp

# 4. Monitor performance
watch -n 1 'rocm-smi'
```

**Solutions**:

1. **Optimize GPU Settings**:
   ```bash
   # Set GPU to performance mode
   rocm-smi --setperflevel high
   
   # Set memory clock
   rocm-smi --setmclk 3
   
   # Set compute clock
   rocm-smi --setsclk 7
   ```

2. **Optimize Model Configuration**:
   ```yaml
   # Increase batch size
   --max-num-batched-tokens: "16384"
   
   # Increase concurrent sequences
   --max-num-seqs: "512"
   
   # Optimize memory utilization
   --gpu-memory-utilization: "0.95"
   ```

## Cache Issues

### Problem: Cache Corruption

**Symptoms**:
- Model loading fails
- Cache validation errors
- Inconsistent model behavior

**Diagnostic Steps**:

```bash
# 1. Check cache integrity
aim-engine cache validate

# 2. Check cache size
aim-engine cache stats

# 3. Check file permissions
ls -la /workspace/model-cache/

# 4. Check disk space
df -h /workspace/model-cache/
```

**Solutions**:

1. **Clear Corrupted Cache**:
   ```bash
   # Remove corrupted cache
   rm -rf /workspace/model-cache/models/Model-Name
   
   # Re-download model
   aim-engine cache download Model/Name
   ```

2. **Rebuild Cache**:
   ```bash
   # Clean all cache
   aim-engine cache cleanup --all
   
   # Re-download models
   aim-engine cache download Model/Name
   ```

## Debug Mode

### Enable Debug Logging

```bash
# Set debug environment variables
export AIM_DEBUG=1
export LOG_LEVEL=DEBUG

# Launch with debug output
aim-engine launch Model/Name 8

# Check debug information
aim-engine debug gpu-info
aim-engine debug recipe-info Model/Name
aim-engine debug config-info Model/Name 8
```

### Debug Commands

```bash
# GPU information
aim-engine debug gpu-info

# Recipe information
aim-engine debug recipe-info Model/Name

# Configuration information
aim-engine debug config-info Model/Name 8

# Cache information
aim-engine debug cache-info

# System information
aim-engine debug system-info
```

## Getting Help

### Collect Diagnostic Information

```bash
#!/bin/bash
# collect-debug-info.sh

echo "=== AIM Engine Debug Information ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "=== System Information ==="
uname -a
cat /etc/os-release
echo ""

echo "=== GPU Information ==="
rocm-smi
echo ""

echo "=== Docker Information ==="
docker version
docker ps -a
echo ""

echo "=== AIM Engine Information ==="
aim-engine debug system-info
aim-engine debug gpu-info
aim-engine cache stats
echo ""

echo "=== Network Information ==="
netstat -tlnp | grep 8000
curl -v http://localhost:8000/health 2>&1
echo ""

echo "=== Disk Information ==="
df -h
du -sh /workspace/model-cache/*
echo ""

echo "=== Memory Information ==="
free -h
echo ""
```

### Submit Bug Report

When submitting a bug report, include:

1. **System Information**:
   - Operating system and version
   - ROCm version
   - Docker version
   - Hardware specifications

2. **Error Details**:
   - Complete error message
   - Command that caused the error
   - Debug output

3. **Configuration**:
   - Model being used
   - GPU count
   - Precision format
   - Recipe file (if custom)

4. **Steps to Reproduce**:
   - Exact commands run
   - Expected vs actual behavior
   - Any recent changes

This troubleshooting guide covers the most common issues and their solutions. For additional help, check the documentation, GitHub issues, or contact the development team.
