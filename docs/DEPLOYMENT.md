# AIM Engine Deployment Guide

## Overview

This guide covers deploying the AIM (AMD Inference Microservice) Engine in various production environments, from single-node deployments to multi-node clusters.

## Prerequisites

### Hardware Requirements
- **AMD Instinct™ GPU**: MI250, MI300X, or MI325X
- **CPU**: 64+ cores recommended for large models
- **RAM**: 256GB+ for large models, 128GB+ for medium models
- **Storage**: NVMe SSD with 1TB+ for model cache
- **Network**: 10Gbps+ for multi-node deployments

### Software Requirements
- **Operating System**: Ubuntu 20.04+ or RHEL/CentOS 8+
- **Docker**: 20.10+ with GPU support
- **ROCm**: 5.7+ for AMD GPU support
- **Python**: 3.8+ (included in container)

## Single-Node Deployment

### Basic Deployment
```bash
# Build the container
./scripts/build.sh

# Launch model with basic configuration
docker run -d \
  --name aim-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --cap-add=SYS_RAWIO \
  -v /workspace/model-cache:/workspace/model-cache \
  -p 8000:8000 \
  --restart unless-stopped \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 8
```

### Production Deployment
```bash
# Create dedicated user and directories
sudo useradd -r -s /bin/false aim-engine
sudo mkdir -p /opt/aim-engine/{logs,config,cache}
sudo chown -R aim-engine:aim-engine /opt/aim-engine

# Create systemd service
sudo tee /etc/systemd/system/aim-engine.service << EOF
[Unit]
Description=AIM Engine Model Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=aim-engine
Group=aim-engine
WorkingDirectory=/opt/aim-engine
ExecStart=/usr/bin/docker run --rm \
  --name aim-qwen-32b \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --cap-add=SYS_RAWIO \
  -v /opt/aim-engine/cache:/workspace/model-cache \
  -v /opt/aim-engine/logs:/var/log/aim \
  -v /opt/aim-engine/config:/opt/aim-engine/config \
  -p 8000:8000 \
  --restart unless-stopped \
  aim-engine:latest \
  aim-engine launch Qwen/Qwen3-32B 8
ExecStop=/usr/bin/docker stop aim-qwen-32b
TimeoutStartSec=600
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
