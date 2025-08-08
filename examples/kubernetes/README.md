# AIM Engine Kubernetes Examples

This directory contains examples for deploying and using AIMs (AMD Inference Microservices) in Kubernetes clusters using the AIM Engine operator.

## Prerequisites

### 1. Kubernetes Cluster
Ensure you have a Kubernetes cluster with:
- AMD GPU support (MI300X, MI325X, etc.)
- At least 16GB RAM per node

#### **Option A: Automated Cluster Setup (Recommended)**
Use the provided script to set up a complete Kubernetes cluster with AMD GPU support:

```bash
# Navigate to the project root
cd /path/to/aim-engine

# Run the complete setup script
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

This script will:
- Install Docker and configure it properly
- Set up a single-node Kubernetes cluster with kubeadm
- Install Calico CNI for networking
- Deploy AMD GPU device plugin
- Set up local storage provisioner
- Install metrics server
- Deploy an initial AIM instance for testing

#### **Option B: Manual Cluster Setup**
If you prefer to set up the cluster manually:

```bash
# 1. Install Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# 2. Install Kubernetes components
sudo apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 3. Initialize the cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 4. Set up kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 5. Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# 6. Install AMD GPU device plugin
kubectl apply -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/main/deploy/k8s-device-plugin.yaml

# 7. Label the node for GPU scheduling
kubectl label node $(hostname) amd.com/gpu=true --overwrite

# 8. Install local storage provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### **Verify Cluster Setup**
After setup, verify your cluster is working:

```bash
# Check cluster status
kubectl get nodes

# Check if AMD GPU is detected
kubectl get nodes -o json | jq '.items[].status.allocatable."amd.com/gpu"'

# Check if pods are running
kubectl get pods --all-namespaces
```

### 2. AIM Engine Operator
Deploy the AIM Engine operator:

```bash
# Deploy operator with testing
cd k8s/operator
./scripts/setup-and-test-operator.sh
```

### 3. Python Dependencies
Install required packages:

```bash
pip install kubernetes requests flask
```

## Available Examples

### 1. Basic AIM Deployment (`basic-aim/`)
Deploy a simple AIM instance with basic configuration.

**Features:**
- Single AIM deployment
- Basic resource configuration
- Health monitoring
- Simple client interaction

**Usage:**
```bash
# Deploy the AIM
kubectl apply -f examples/kubernetes/basic-aim/

# Check status
kubectl get aimendpoint -n aim-engine

# Run the client
python3 examples/kubernetes/basic-aim/client.py
```

### 2. Multi-Model AIMs (`multi-model/`)
Deploy multiple AIM instances with different models.

**Features:**
- Multiple AIM deployments
- Different model configurations
- Load balancing between models
- Model comparison

**Usage:**
```bash
# Deploy multiple AIMs
kubectl apply -f examples/kubernetes/multi-model/

# Check all AIMs
kubectl get aimendpoint -n aim-engine

# Run the multi-model client
python3 examples/kubernetes/multi-model/client.py
```

### 3. AIM with Caching (`cached-aim/`)
Deploy an AIM with persistent caching enabled.

**Features:**
- Persistent volume caching
- Model caching across restarts
- Cache monitoring
- Performance comparison

**Usage:**
```bash
# Deploy cached AIM
kubectl apply -f examples/kubernetes/cached-aim/

# Monitor cache usage
kubectl get pvc -n aim-engine

# Run the cached client
python3 examples/kubernetes/cached-aim/client.py
```

### 4. Scalable AIM (`scalable-aim/`)
Deploy an AIM with horizontal pod autoscaling.

**Features:**
- Horizontal Pod Autoscaler
- Load-based scaling
- Performance monitoring
- Load testing

**Usage:**
```bash
# Deploy scalable AIM
kubectl apply -f examples/kubernetes/scalable-aim/

# Check HPA status
kubectl get hpa -n aim-engine

# Run load test
python3 examples/kubernetes/scalable-aim/load_test.py
```

### 5. AIM with Monitoring (`monitored-aim/`)
Deploy an AIM with comprehensive monitoring.

**Features:**
- Prometheus metrics
- Grafana dashboards
- Health checks
- Performance alerts

**Usage:**
```bash
# Deploy monitored AIM
kubectl apply -f examples/kubernetes/monitored-aim/

# Access Grafana dashboard
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Run the monitored client
python3 examples/kubernetes/monitored-aim/client.py
```

### 6. Production AIM (`production-aim/`)
Production-ready AIM deployment with all features.

**Features:**
- High availability
- Resource limits
- Security policies
- Backup and recovery
- Comprehensive monitoring

**Usage:**
```bash
# Deploy production AIM
kubectl apply -f examples/kubernetes/production-aim/

# Check all resources
kubectl get all -n aim-engine

# Run production tests
python3 examples/kubernetes/production-aim/test_suite.py
```

## Common Commands

### Check AIM Status
```bash
# List all AIMs
kubectl get aimendpoint -n aim-engine

# Get detailed status
kubectl describe aimendpoint <aim-name> -n aim-engine

# Check AIM pods
kubectl get pods -n aim-engine -l app.kubernetes.io/name=aim-endpoint

# Check AIM services
kubectl get svc -n aim-engine
```

### Access AIM Services
```bash
# Port forward to access AIM
kubectl port-forward svc/<aim-name> 8000:8000 -n aim-engine

# Test AIM health
curl http://localhost:8000/health

# Test AIM models
curl http://localhost:8000/v1/models
```

### Monitor AIM Performance
```bash
# Check AIM logs
kubectl logs -f deployment/<aim-name> -n aim-engine

# Check resource usage
kubectl top pods -n aim-engine

# Check HPA status
kubectl get hpa -n aim-engine
```

## Cleanup

### Remove All Examples
```bash
# Remove all AIMs
kubectl delete aimendpoint --all -n aim-engine

# Remove all recipes
kubectl delete aimrecipe --all -n aim-engine

# Remove all PVCs
kubectl delete pvc --all -n aim-engine
```

### Remove Specific Example
```bash
# Remove specific example
kubectl delete -f examples/kubernetes/<example-name>/
```

## Troubleshooting

### AIM Not Starting
```bash
# Check pod events
kubectl describe pod -n aim-engine

# Check operator logs
kubectl logs -n aim-engine-system -l control-plane=controller-manager

# Check resource availability
kubectl get nodes -o json | jq '.items[].status.allocatable'
```

### Service Not Accessible
```bash
# Check service status
kubectl get svc -n aim-engine

# Check endpoint status
kubectl get endpoints -n aim-engine

# Test connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://<aim-service>:8000/health
```

### Performance Issues
```bash
# Check resource usage
kubectl top pods -n aim-engine

# Check HPA status
kubectl get hpa -n aim-engine

# Check AIM metrics
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
```

## Next Steps

After running these examples, you can:

1. **Customize Configurations**: Modify the YAML files to suit your needs
2. **Add More Models**: Create new AIM recipes for different models
3. **Scale Up**: Add more GPU nodes to run multiple AIMs
4. **Monitor Production**: Set up comprehensive monitoring and alerting
5. **Integrate Applications**: Connect your applications to the AIMs

For more information, see the main [README.md](../../README.md) and [AIM Engine Operator documentation](../../k8s/operator/README.md). 