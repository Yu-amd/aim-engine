#!/bin/bash

# AIM Engine Kubernetes Setup Script
# This script sets up a complete Kubernetes cluster with AMD GPU support
# and prepares it for AIM Engine operator and example deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
KUBERNETES_VERSION="1.28"
CALICO_VERSION="v3.26.1"
REGISTRY_PORT="5000"
AIM_ENGINE_NAMESPACE="aim-engine"

log_info "Starting AIM Engine Kubernetes cluster setup..."

# Step 1: System preparation
log_info "Step 1: Preparing system..."
{
    # Update system
    apt update && apt upgrade -y
    
    # Install required packages
    apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    
    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load kernel modules
    modprobe overlay
    modprobe br_netfilter
    
    # Configure kernel parameters
    cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl --system
    
    log_success "System preparation completed"
} || {
    log_error "System preparation failed"
    exit 1
}

# Step 2: Install and configure Docker robustly
log_info "Step 2: Installing and configuring Docker robustly..."

# Function to check if Docker is working
check_docker() {
    if docker ps > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to install Docker completely
install_docker_complete() {
    log_info "Performing complete Docker installation..."
    
    # Stop any existing Docker processes
    pkill -f dockerd || true
    pkill -f docker || true
    
    # Remove all Docker packages
    apt remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    apt autoremove -y
    
    # Clean up Docker directories
    rm -rf /var/lib/docker /etc/docker /var/run/docker.sock /etc/systemd/system/docker.service.d 2>/dev/null || true
    
    # Update and install Docker
    apt update
    apt install -y docker.io docker-compose
    
    # Create Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
    
    # Start and enable Docker service
    systemctl daemon-reload
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $USER || true
    
    # Wait for Docker to be ready
    sleep 10
    
    # Verify Docker is working
    if check_docker; then
        log_success "Docker installed and working"
        return 0
    else
        return 1
    fi
}

# Main Docker setup logic
{
    # First, check if Docker is already working
    if check_docker; then
        log_info "Docker is already working"
        docker --version
        docker ps
        log_success "Docker is ready"
    else
        log_info "Docker is not working, attempting to fix..."
        
        # Check if Docker is installed
        if command -v docker &> /dev/null; then
            log_info "Docker binary found, checking service status..."
            
            # Check if systemd service exists and try to start it
            if systemctl list-unit-files | grep -q "docker.service"; then
                log_info "Docker systemd service found, attempting to start..."
                systemctl daemon-reload
                systemctl start docker
                systemctl enable docker
                sleep 5
                
                if check_docker; then
                    log_success "Docker started via systemd"
                else
                    log_warning "Systemd start failed, checking for dockerd binary..."
                    
                    # Check if dockerd binary exists
                    DOCKERD_PATH=$(which dockerd 2>/dev/null || find /usr -name "dockerd" 2>/dev/null | head -1)
                    if [[ -n "$DOCKERD_PATH" ]]; then
                        log_info "Found dockerd at $DOCKERD_PATH, trying manual start..."
                        pkill -f dockerd || true
                        nohup $DOCKERD_PATH > /var/log/docker.log 2>&1 &
                        sleep 10
                        
                        if check_docker; then
                            log_success "Docker started manually"
                        else
                            log_warning "Manual start failed, performing complete reinstall..."
                            install_docker_complete
                        fi
                    else
                        log_warning "Dockerd binary not found, performing complete reinstall..."
                        install_docker_complete
                    fi
                fi
            else
                log_warning "Docker systemd service not found, performing complete reinstall..."
                install_docker_complete
            fi
        else
            log_info "Docker not installed, performing fresh installation..."
            install_docker_complete
        fi
        
        # Final verification
        if check_docker; then
            log_success "Docker is now working"
            docker --version
            docker ps
        else
            log_error "All Docker installation attempts failed"
            log_info "Trying one final attempt with official Docker script..."
            
            # Last resort: official Docker installation
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            systemctl start docker
            systemctl enable docker
            usermod -aG docker $USER || true
            sleep 10
            
            if check_docker; then
                log_success "Docker working via official installation"
            else
                log_error "All Docker installation methods failed"
                log_info "Docker logs:"
                journalctl -u docker --no-pager -n 20 || true
                log_info "System logs:"
                journalctl --no-pager -n 20 || true
                exit 1
            fi
        fi
    fi
    
    # Ensure Docker is accessible to the current user
    if ! docker ps > /dev/null 2>&1; then
        log_warning "Docker not accessible to current user, using sudo for this session..."
        
        # Add user to docker group for future sessions
        usermod -aG docker $USER || true
        
        # Check if sudo docker works
        if sudo docker ps > /dev/null 2>&1; then
            log_success "Docker accessible via sudo"
            # Create a function for this session
            eval 'docker() { sudo docker "$@"; }'
        else
            log_error "Docker not accessible even with sudo"
            log_info "You may need to restart your shell session or run: newgrp docker"
            exit 1
        fi
    fi
    
} || {
    log_error "Docker setup failed"
    exit 1
}

# Step 3: Install containerd
log_info "Step 3: Installing containerd..."
{
    # Install containerd
    apt install -y containerd
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd
    
    log_success "Containerd installed and configured"
} || {
    log_error "Containerd installation failed"
    exit 1
}

# Step 4: Setup local container registry
log_info "Step 4: Setting up local container registry..."
{
    # Function to check if registry is working
    check_registry() {
        if curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    }
    
    # Function to start registry
    start_registry() {
        log_info "Starting local registry..."
        
        # Remove any existing registry container
        docker rm -f local-registry 2>/dev/null || true
        
        # Start new registry
        docker run -d -p ${REGISTRY_PORT}:${REGISTRY_PORT} --name local-registry --restart=always registry:2
        
        # Wait for registry to be ready
        log_info "Waiting for registry to be ready..."
        for i in {1..30}; do
            if check_registry; then
                log_success "Registry is responding"
                return 0
            fi
            sleep 2
        done
        
        return 1
    }
    
    # Check if registry is already working
    if check_registry; then
        log_info "Local registry is already running and responding"
    else
        # Check if registry container exists but not responding
        if docker ps -a | grep -q "local-registry"; then
            log_info "Registry container exists but not responding, restarting..."
            docker start local-registry
            sleep 5
            
            if ! check_registry; then
                log_warning "Registry restart failed, recreating..."
                start_registry
            fi
        else
            log_info "No registry container found, creating new one..."
            start_registry
        fi
        
        # Final verification
        if check_registry; then
            log_success "Local registry is working"
        else
            log_error "Failed to start local registry"
            log_info "Docker status:"
            docker ps -a
            log_info "Registry logs:"
            docker logs local-registry 2>/dev/null || true
            exit 1
        fi
    fi
    
    # Test registry functionality
    log_info "Testing registry functionality..."
    curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog
    
    log_success "Local container registry setup completed"
} || {
    log_error "Local registry setup failed"
    exit 1
}

# Step 5: Build and push AIM Engine image
log_info "Step 5: Building and pushing AIM Engine image..."
{
    # Change to project directory
    cd /root/aim-engine
    
    # Build the image
    ./scripts/build-aim-vllm.sh
    
    # Tag and push to local registry
    docker tag aim-vllm:latest localhost:${REGISTRY_PORT}/aim-vllm:latest
    docker push localhost:${REGISTRY_PORT}/aim-vllm:latest
    
    log_success "AIM Engine image built and pushed to local registry"
} || {
    log_error "Image build/push failed"
    exit 1
}

# Step 6: Install Kubernetes components
log_info "Step 6: Installing Kubernetes components..."
{
    # Add Kubernetes repository
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update and install Kubernetes components
    apt update
    apt install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    log_success "Kubernetes components installed"
} || {
    log_error "Kubernetes installation failed"
    exit 1
}

# Step 7: Initialize Kubernetes cluster
log_info "Step 7: Initializing Kubernetes cluster..."
{
    # Initialize cluster
    kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
    
    # Create kubeconfig for current user
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Create kubeconfig for other common users
    for user in ubuntu root; do
        if id "$user" &>/dev/null; then
            mkdir -p /home/$user/.kube
            cp -i /etc/kubernetes/admin.conf /home/$user/.kube/config
            chown $user:$user /home/$user/.kube/config
        fi
    done
    
    # Set KUBECONFIG for current session
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    log_success "Kubernetes cluster initialized"
} || {
    log_error "Kubernetes cluster initialization failed"
    exit 1
}

# Step 8: Install Calico CNI
log_info "Step 8: Installing Calico CNI..."
{
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
    
    # Wait for Calico to be ready
    kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
    
    log_success "Calico CNI installed"
} || {
    log_error "Calico CNI installation failed"
    exit 1
}

# Step 9: Install metrics server
log_info "Step 9: Installing metrics server..."
{
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Wait for metrics server to be ready
    kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
    
    log_success "Metrics server installed"
} || {
    log_error "Metrics server installation failed"
    exit 1
}

# Step 10: Install local storage provisioner
log_info "Step 10: Installing local storage provisioner..."
{
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
    
    # Set as default storage class
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    
    # Add tolerations to local-path-provisioner to allow scheduling on control-plane
    kubectl patch deployment local-path-provisioner -n local-path-storage -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
    
    # Wait for local-path-provisioner to be ready
    kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=300s
    
    log_success "Local storage provisioner installed"
} || {
    log_error "Local storage provisioner installation failed"
    exit 1
}

# Step 11: Setup AMD GPU support
log_info "Step 11: Setting up AMD GPU support..."
{
    # Install ROCm packages
    apt install -y rocm-hip-sdk rocm-opencl-sdk
    
    # Create GPU device plugin for AMD MI300X (compatible with K8s 1.28)
    cat > /tmp/amd-gpu-device-plugin.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: amd-gpu-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: amd-gpu-device-plugin
  template:
    metadata:
      labels:
        name: amd-gpu-device-plugin
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: amd-gpu-device-plugin
        image: rocm/k8s-device-plugin:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
          - name: kfd
            mountPath: /dev/kfd
          - name: dri
            mountPath: /dev/dri
        env:
          - name: KUBECONFIG
            value: /var/lib/kubelet/device-plugins/kubeconfig
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
        - name: kfd
          hostPath:
            path: /dev/kfd
        - name: dri
          hostPath:
            path: /dev/dri
      nodeSelector:
        kubernetes.io/os: linux
EOF
    
    kubectl apply -f /tmp/amd-gpu-device-plugin.yaml
    
    # Wait for GPU device plugin to be ready
    kubectl wait --for=condition=ready pod -l name=amd-gpu-device-plugin -n kube-system --timeout=300s
    
    # Add GPU label to the node
    kubectl label node $(hostname) amd.com/gpu=true --overwrite
    
    log_success "AMD GPU support configured"
} || {
    log_error "AMD GPU setup failed"
    exit 1
}

# Step 12: Create AIM Engine namespace
log_info "Step 12: Creating AIM Engine namespace..."
{
    # Check if namespace exists and is stuck in terminating
    if kubectl get namespace ${AIM_ENGINE_NAMESPACE} 2>/dev/null | grep -q "Terminating"; then
        log_warning "Namespace ${AIM_ENGINE_NAMESPACE} is stuck in terminating state, forcing deletion..."
        kubectl delete namespace ${AIM_ENGINE_NAMESPACE} --force --grace-period=0
        kubectl patch namespace ${AIM_ENGINE_NAMESPACE} -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        sleep 10
    fi
    
    kubectl create namespace ${AIM_ENGINE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "AIM Engine namespace created"
} || {
    log_error "Namespace creation failed"
    exit 1
}

# Step 12: Install Helm
log_info "Step 12: Installing Helm..."
{
    if command -v helm &> /dev/null; then
        log_info "Helm is already installed"
        helm version
    else
        # Install Helm
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        apt update
        apt install -y helm
        
        log_success "Helm installed"
    fi
    
    # Verify Helm can connect to the cluster
    if ! helm list --all-namespaces > /dev/null 2>&1; then
        log_warning "Helm cannot connect to cluster, this may cause issues"
    fi
} || {
    log_error "Helm installation failed"
    exit 1
}

# Step 13: Setup AIM Engine Namespace (without deploying AIM instance)
log_info "Step 13: Setting up AIM Engine namespace..."
{
    # Create namespace for AIM Engine examples
    kubectl create namespace ${AIM_ENGINE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "AIM Engine namespace ready for examples"
} || {
    log_error "AIM Engine namespace setup failed"
    exit 1
}

# Step 14: Setup complete
log_info "Step 14: Kubernetes cluster setup complete!"
{
    NODE_IP=$(hostname -I | awk '{print $1}')
    
    log_success "Kubernetes cluster is ready!"
    log_info "Cluster Status:"
    kubectl get nodes
    echo
    log_info "GPU Availability:"
    kubectl get nodes -o json | jq '.items[0].status.allocatable."amd.com/gpu"' 2>/dev/null || echo "GPU information not available"
    echo
    log_info "Next Steps:"
    log_info "1. Deploy the AIM Engine operator: cd k8s/operator && ./scripts/setup-and-test-operator.sh"
    log_info "2. Run Kubernetes examples: cd examples/kubernetes && ./setup.sh"
    log_info "3. Or use Docker examples: cd examples/docker && ./quick_start.sh"
    
} || {
    log_error "Final setup verification failed"
    exit 1
}

# Final success message
log_success "🎉 AIM Engine Kubernetes setup completed successfully!"
log_info "Your cluster is ready with:"
log_info "  - Kubernetes v${KUBERNETES_VERSION}"
log_info "  - AMD GPU support"
log_info "  - Local container registry"
log_info "  - AIM Engine Docker image built and available"
log_info "  - Ready for operator and example deployments"

# Display useful commands
echo ""
log_info "Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get namespaces"
echo "  docker images | grep aim-vllm"
echo "  curl http://localhost:${REGISTRY_PORT}/v2/_catalog"
echo "" 