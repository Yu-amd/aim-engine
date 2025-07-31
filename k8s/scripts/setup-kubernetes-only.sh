#!/bin/bash

# AIM Engine - Kubernetes Cluster Setup (Only)
# This script sets up a proper Kubernetes cluster without Docker registry complications

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

log_info "Starting Kubernetes cluster setup..."

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

# Step 2: Install containerd
log_info "Step 2: Installing containerd..."
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

# Step 3: Install Kubernetes components
log_info "Step 3: Installing Kubernetes components..."
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

# Step 4: Initialize Kubernetes cluster
log_info "Step 4: Initializing Kubernetes cluster..."
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

# Step 5: Install Calico CNI
log_info "Step 5: Installing Calico CNI..."
{
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    
    # Wait for Calico to be ready
    kubectl wait --for=condition=ready pod -l name=calico-node -n kube-system --timeout=300s
    
    log_success "Calico CNI installed"
} || {
    log_error "Calico installation failed"
    exit 1
}

# Step 6: Install AMD GPU device plugin
log_info "Step 6: Installing AMD GPU device plugin..."
{
    # Create AMD GPU device plugin
    cat > /tmp/amd-gpu-device-plugin.yaml << EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: amd-gpu-device-plugin-daemonset
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
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - image: rocm/k8s-device-plugin:latest
        name: amd-gpu-device-plugin
        args: ["--pass-device-specs", "--device-id-strategy=uuid"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
        - name: kfd
          mountPath: /dev/kfd
        - name: dri
          mountPath: /dev/dri
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
    
    log_success "AMD GPU support configured"
} || {
    log_error "AMD GPU setup failed"
    exit 1
}

# Step 7: Create namespaces for AIM Engine
log_info "Step 7: Creating namespaces..."
{
    kubectl create namespace aim-engine-operator --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace aim-engine --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespaces created"
} || {
    log_error "Namespace creation failed"
    exit 1
}

# Final success message
log_success "🎉 Kubernetes cluster setup completed successfully!"
log_info "Your cluster is ready with:"
log_info "  - Kubernetes v${KUBERNETES_VERSION}"
log_info "  - Calico CNI"
log_info "  - AMD GPU support"
log_info "  - Namespaces: aim-engine-operator, aim-engine"

# Display useful commands
echo ""
log_info "Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl get nodes --show-labels | grep amd.com/gpu"
echo "  kubectl get pods -n kube-system | grep amd-gpu-device-plugin"
echo ""
log_info "Next step: Deploy the AIM Engine operator!"
echo "  cd k8s/operator"
echo "  ./scripts/install.sh"
echo "" 