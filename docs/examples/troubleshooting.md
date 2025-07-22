# AIM Engine Troubleshooting Guide

## 🔍 **Diagnostic Commands**

### **System Information**
```bash
# Check system resources
free -h                    # Memory usage
df -h                      # Disk space
lscpu                      # CPU information
rocm-smi                   # AMD GPU availability and usage
```

### **Docker Status**
```bash
# Check Docker status
docker info                # Docker configuration
docker ps -a              # All containers
docker images             # Available images
docker system df          # Docker disk usage
```

### **GPU Information**
```bash
# Check AMD GPU status
rocm-smi                   # Basic GPU information
rocm-smi --showuse         # GPU utilization
rocm-smi --showmemuse      # Memory usage
rocm-smi --showtemp        # Temperature
rocm-smi --showclocks      # Clock frequencies
```

## 🚨 **Common Issues and Solutions**

### **1. GPU Not Available**

#### **Symptoms**
- Error: "No AMD GPUs found"
- Error: "ROCm not available"
- Container fails to start with GPU access

#### **Diagnosis**
```bash
# Check if ROCm is installed
rocm-smi

# Check ROCm installation
dpkg -l | grep rocm

# Check GPU drivers
lspci | grep -i amd
```

#### **Solutions**

**Install ROCm Drivers:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install rocm-dkms

# Restart system
sudo reboot
```

**Verify Installation:**
```bash
# Check ROCm installation
rocm-smi

# Test GPU access
docker run --rm --gpus all rocm/pytorch:latest rocm-smi
```

### **2. Memory Issues**

#### **Symptoms**
- Error: "ROCm out of memory"
- Container crashes during model loading
- Poor performance with large models

#### **Diagnosis**
```bash
# Check GPU memory usage
rocm-smi --showmemuse

# Monitor memory in real-time
watch -n 1 'rocm-smi --showmemuse'
```

#### **Solutions**

**Reduce GPU Count:**
```bash
# Use fewer GPUs
aim-engine launch Qwen/Qwen3-32B 2  # Instead of 4

# Use single GPU
aim-engine launch Llama-3-8B 1
```

**Use Lower Precision:**
```bash
# Use FP16 instead of BF16
aim-engine launch Qwen/Qwen3-32B 4 --precision fp16

# Use INT8 quantization
aim-engine launch Qwen/Qwen3-32B 4 --precision int8
```

**Optimize Memory Allocation:**
```bash
# Set memory optimization
export PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512

# Reduce batch size
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4 --max-batch-size 8
```

### **3. Model Download Issues**

#### **Symptoms**
- Error: "Model not found"
- Slow download speeds
- Network timeouts

#### **Diagnosis**
```bash
# Test network connectivity
curl -I https://huggingface.co/Qwen/Qwen3-32B

# Check DNS resolution
nslookup huggingface.co

# Test download speed
wget --report-speed=bits https://huggingface.co/Qwen/Qwen3-32B/resolve/main/config.json
```

#### **Solutions**

**Use Alternative Mirrors:**
```bash
# Set alternative endpoint
export HF_ENDPOINT=https://hf-mirror.com

# Or use local mirror
export HF_ENDPOINT=http://your-local-mirror.com
```

**Clear Corrupted Cache:**
```bash
# Remove specific model cache
rm -rf /workspace/model-cache/models/Qwen--Qwen3-32B/

# Clear all cache
rm -rf /workspace/model-cache/models/*

# Reinitialize cache
aim-engine cache stats
```

**Use Pre-downloaded Models:**
```bash
# Download model manually
git lfs install
git clone https://huggingface.co/Qwen/Qwen3-32B /path/to/local/model

# Use local model
aim-engine launch /path/to/local/model 4
```

### **4. Container Issues**

#### **Symptoms**
- Container fails to start
- Container exits immediately
- Port conflicts

#### **Diagnosis**
```bash
# Check container logs
docker logs <container-name>

# Check container status
docker ps -a

# Check port usage
netstat -tulpn | grep :8000
```

#### **Solutions**

**Check Docker Configuration:**
```bash
# Verify Docker GPU support
docker run --rm --gpus all rocm/pytorch:latest rocm-smi

# Check Docker daemon
sudo systemctl status docker

# Restart Docker if needed
sudo systemctl restart docker
```

**Fix Port Conflicts:**
```bash
# Use different port
aim-engine launch Qwen/Qwen3-32B 4 --port 8001

# Stop conflicting container
docker stop <container-name>

# Check what's using the port
lsof -i :8000
```

**Container Resource Limits:**
```bash
# Increase memory limit
docker run --rm --gpus all --memory=32g \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4

# Increase shared memory
docker run --rm --gpus all --shm-size=8g \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 4
```

### **5. Performance Issues**

#### **Symptoms**
- Slow inference speed
- High latency
- Poor throughput

#### **Diagnosis**
```bash
# Monitor GPU utilization
watch -n 1 'rocm-smi --showuse'

# Check container performance
docker stats <container-name>

# Monitor system resources
htop
```

#### **Solutions**

**Optimize Model Configuration:**
```bash
# Use optimal precision
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16

# Increase batch size
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4 --max-batch-size 32

# Optimize sequence length
aim-engine serve Qwen/Qwen3-32B --tensor-parallel-size 4 --max-model-len 4096
```

**System Optimization:**
```bash
# Set performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Optimize memory allocation
export PYTORCH_ROCM_ALLOC_CONF=max_split_size_mb:512

# Disable CPU frequency scaling
sudo cpupower frequency-set -g performance
```

### **6. Cache Issues**

#### **Symptoms**
- Cache not working
- Models re-downloading
- Cache corruption

#### **Diagnosis**
```bash
# Check cache status
aim-engine cache stats

# Verify cache directory
ls -la /workspace/model-cache/

# Check cache permissions
ls -la /workspace/model-cache/models/
```

#### **Solutions**

**Fix Cache Permissions:**
```bash
# Fix ownership
sudo chown -R $USER:$USER /workspace/model-cache

# Fix permissions
chmod -R 755 /workspace/model-cache

# Reinitialize cache
aim-engine cache stats
```

**Rebuild Cache:**
```bash
# Clear corrupted cache
rm -rf /workspace/model-cache/models/*

# Rebuild cache index
aim-engine cache rebuild

# Verify cache
aim-engine cache list
```

## 🔧 **Advanced Troubleshooting**

### **Debug Mode**

```bash
# Enable debug logging
export AIM_DEBUG=1
export AIM_LOG_LEVEL=DEBUG

# Run with verbose output
aim-engine launch Qwen/Qwen3-32B 4 --verbose
```

### **System Logs**

```bash
# Check system logs
sudo journalctl -f

# Check Docker logs
sudo journalctl -u docker -f

# Check ROCm logs
sudo dmesg | grep -i amd
```

### **Performance Profiling**

```bash
# Profile GPU usage
rocm-smi --showuse

# Monitor in real-time
watch -n 1 'rocm-smi --showuse && rocm-smi --showtemp'

# Check thermal status
rocm-smi --showtemp
```

## 📞 **Getting Help**

### **Information to Collect**

When reporting issues, please include:

1. **System Information:**
   ```bash
   uname -a
   lsb_release -a
   rocm-smi
   ```

2. **Docker Information:**
   ```bash
   docker version
   docker info
   ```

3. **AIM Engine Version:**
   ```bash
   aim-engine --version
   ```

4. **Error Logs:**
   ```bash
   docker logs <container-name>
   aim-engine cache stats
   ```

5. **Configuration:**
   ```bash
   env | grep -E "(AIM|HF|PYTORCH)"
   ```

### **Support Channels**

- **Documentation**: Check this guide and other docs
- **Issues**: Open an issue on the project repository
- **Community**: Check discussions and forums
- **Logs**: Always include relevant logs when reporting issues

## 🎯 **Prevention Tips**

### **1. Regular Maintenance**
```bash
# Clean up old containers
docker container prune

# Clean up unused images
docker image prune

# Monitor disk usage
df -h
```

### **2. Resource Monitoring**
```bash
# Set up monitoring
watch -n 60 'rocm-smi --showuse && echo "---" && df -h'

# Monitor cache usage
watch -n 300 'du -sh /workspace/model-cache'
```

### **3. Backup Important Data**
```bash
# Backup cache
tar -czf model-cache-backup-$(date +%Y%m%d).tar.gz /workspace/model-cache

# Backup configurations
cp aim-config.yaml aim-config-backup.yaml
```

---

**AIM Engine** - AMD Inference Microservice! 🚀 