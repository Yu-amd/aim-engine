#!/bin/bash

# AIM Engine - Kubernetes Cluster Setup Script
# This script sets up a production-ready Kubernetes cluster on AMD GPU nodes

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
KUBERNETES_VERSION="1.28.0"
CONTAINERD_VERSION="1.7.0"
HELM_VERSION="3.12.0"
KUBECTL_VERSION="1.28.0"
NVIDIA_CONTAINER_RUNTIME_VERSION="3.8.0"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_warning "This script is tested on Ubuntu/Debian. Other distributions may require modifications."
    fi
    
    # Check memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 8 ]]; then
        log_error "At least 8GB RAM required. Found: ${mem_gb}GB"
        exit 1
    fi
    
    # Check disk space
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 20 ]]; then
        log_error "At least 20GB free disk space required. Found: ${disk_gb}GB"
        exit 1
    fi
    
    log_success "System requirements met"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt update
    apt upgrade -y
    log_success "System packages updated"
}

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        git \
        jq \
        htop \
        nvme-cli \
        nfs-common \
        chrony \
        ufw \
        fail2ban
    
    log_success "Required packages installed"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow Kubernetes ports
    ufw allow 6443/tcp  # Kubernetes API server
    ufw allow 2379:2380/tcp  # etcd
    ufw allow 10250/tcp  # Kubelet
    ufw allow 10251/tcp  # kube-scheduler
    ufw allow 10252/tcp  # kube-controller-manager
    ufw allow 10255/tcp  # Kubelet read-only
    ufw allow 30000:32767/tcp  # NodePort services
    
    # Allow Calico ports
    ufw allow 179/tcp  # BGP
    ufw allow 4789/udp  # VXLAN
    
    log_success "Firewall configured"
}

# Disable swap
disable_swap() {
    log_info "Disabling swap..."
    
    # Disable swap immediately
    swapoff -a
    
    # Remove swap from fstab
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    log_success "Swap disabled"
}

# Configure kernel modules
configure_kernel_modules() {
    log_info "Configuring kernel modules..."
    
    # Load required modules
    modprobe overlay
    modprobe br_netfilter
    
    # Make modules persistent
    cat > /etc/modules-load.d/containerd.conf << EOF
overlay
br_netfilter
EOF
    
    # Configure sysctl
    cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    
    # Apply sysctl
    sysctl --system
    
    log_success "Kernel modules configured"
}

# Install containerd
install_containerd() {
    log_info "Installing containerd..."
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    apt update
    
    # Install containerd
    apt install -y containerd.io
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Enable systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Restart containerd
    systemctl restart containerd
    systemctl enable containerd
    
    log_success "Containerd installed and configured"
}

# Install Kubernetes components
install_kubernetes() {
    log_info "Installing Kubernetes components..."
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update package list
    apt update
    
    # Install Kubernetes components
    apt install -y kubelet=${KUBERNETES_VERSION}-1.1 kubeadm=${KUBERNETES_VERSION}-1.1 kubectl=${KUBERNETES_VERSION}-1.1
    
    # Hold packages to prevent automatic updates
    apt-mark hold kubelet kubeadm kubectl
    
    log_success "Kubernetes components installed"
}

# Install Helm
install_helm() {
    log_info "Installing Helm..."
    
    # Download Helm
    curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -xz
    
    # Move to /usr/local/bin
    mv linux-amd64/helm /usr/local/bin/
    rm -rf linux-amd64
    
    log_success "Helm installed"
}

# Initialize Kubernetes cluster
initialize_cluster() {
    log_info "Initializing Kubernetes cluster..."
    
    # Initialize cluster
    kubeadm init \
        --pod-network-cidr=10.244.0.0/16 \
        --service-cidr=10.96.0.0/12 \
        --apiserver-advertise-address=$(hostname -I | awk '{print $1}') \
        --kubernetes-version=${KUBERNETES_VERSION} \
        --ignore-preflight-errors=all
    
    # Create kubeconfig for root user
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Create kubeconfig for regular users
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube
    
    log_success "Kubernetes cluster initialized"
}

# Install Calico CNI
install_calico() {
    log_info "Installing Calico CNI..."
    
    # Install Calico
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    
    # Wait for Calico to be ready
    log_info "Waiting for Calico to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
    
    log_success "Calico CNI installed"
}

# Install metrics server
install_metrics_server() {
    log_info "Installing metrics server..."
    
    # Install metrics server
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Patch metrics server to work with self-signed certificates
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    
    log_success "Metrics server installed"
}

# Install AMD GPU operator
install_amd_gpu_operator() {
    log_info "Installing AMD GPU operator..."
    
    # Add AMD GPU operator repository
    helm repo add amd-gpu-operator https://rocm.github.io/amd-gpu-operator
    helm repo update
    
    # Install AMD GPU operator
    helm install amd-gpu-operator amd-gpu-operator/amd-gpu-operator \
        --namespace gpu-operator-system \
        --create-namespace \
        --set driver.enabled=true \
        --set devicePlugin.enabled=true \
        --set migManager.enabled=false \
        --set nodeFeatureDiscovery.enabled=true \
        --set gfd.enabled=true
    
    log_success "AMD GPU operator installed"
}

# Configure storage
configure_storage() {
    log_info "Configuring storage..."
    
    # Install local-path-provisioner for local storage
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
    
    # Set as default storage class
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    
    log_success "Storage configured"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."
    
    # Create aim-engine namespace
    kubectl create namespace aim-engine
    
    # Create monitoring namespace
    kubectl create namespace monitoring
    
    log_success "Namespaces created"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check nodes
    log_info "Kubernetes nodes:"
    kubectl get nodes
    
    # Check pods
    log_info "System pods:"
    kubectl get pods -n kube-system
    
    # Check GPU operator
    log_info "GPU operator pods:"
    kubectl get pods -n gpu-operator-system
    
    # Check GPU resources
    log_info "GPU resources:"
    kubectl get nodes -o json | jq '.items[].status.allocatable | select(."amd.com/gpu")'
    
    log_success "Installation verification completed"
}

# Print next steps
print_next_steps() {
    log_success "Kubernetes cluster setup completed!"
    echo
    echo "Next steps:"
    echo "1. Join worker nodes (if any):"
    echo "   kubeadm token create --print-join-command"
    echo
    echo "2. Deploy AIM Engine:"
    echo "   cd k8s"
    echo "   helm install aim-engine ./helm"
    echo
    echo "3. Check cluster status:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods --all-namespaces"
    echo
    echo "4. Access cluster:"
    echo "   kubectl cluster-info"
    echo
    echo "5. GPU verification:"
    echo "   kubectl get nodes -o json | jq '.items[].status.allocatable'"
    echo
}

# Main execution
main() {
    log_info "Starting Kubernetes cluster setup for AMD GPU node..."
    
    check_root
    check_system_requirements
    update_system
    install_packages
    configure_firewall
    disable_swap
    configure_kernel_modules
    install_containerd
    install_kubernetes
    install_helm
    initialize_cluster
    install_calico
    install_metrics_server
    install_amd_gpu_operator
    configure_storage
    create_namespaces
    verify_installation
    print_next_steps
    
    log_success "Kubernetes cluster setup completed successfully!"
}

# Run main function
main "$@" 