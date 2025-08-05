#!/bin/bash

# AIM Engine Kubernetes Setup Script
# This script sets up a complete Kubernetes cluster with AMD GPU support
# and deploys AIM Engine with all necessary configurations

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

# Step 2: Install Docker as systemd service
log_info "Step 2: Installing Docker as systemd service..."
{
    # Check if Docker is already running
    if docker ps > /dev/null 2>&1; then
        log_info "Docker is already running, skipping installation"
        docker --version
        docker ps
        log_success "Docker is working"
    else
        # Check if Docker is installed but not running
        if command -v docker &> /dev/null; then
            log_info "Docker is installed but not running, attempting to start..."
            
            # Try to start Docker daemon manually if systemd service doesn't exist
            if ! systemctl start docker 2>/dev/null; then
                log_info "Systemd service not found, trying manual start..."
                # Look for dockerd binary
                DOCKERD_PATH=$(find /usr -name "dockerd" 2>/dev/null | head -1)
                if [[ -n "$DOCKERD_PATH" ]]; then
                    nohup $DOCKERD_PATH > /var/log/docker.log 2>&1 &
                    sleep 5
                else
                    log_warning "Dockerd binary not found, reinstalling Docker..."
                    # Remove existing Docker installation
                    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
                    apt autoremove -y
                    
                    # Install Docker properly
                    apt update
                    apt install -y docker.io docker-compose
                    
                    # Start and enable Docker service
                    systemctl start docker
                    systemctl enable docker
                fi
            fi
            
            # Add current user to docker group
            usermod -aG docker $USER || true
            
            # Verify Docker is working
            if docker ps > /dev/null 2>&1; then
                docker --version
                docker ps
                log_success "Docker is now working"
            else
                log_error "Failed to start Docker daemon"
                exit 1
            fi
        else
            # Install Docker from scratch
            log_info "Installing Docker from scratch..."
            apt update
            apt install -y docker.io docker-compose
            
            # Start and enable Docker service
            systemctl start docker
            systemctl enable docker
            
            # Add current user to docker group
            usermod -aG docker $USER || true
            
            # Verify Docker is working
            docker --version
            docker ps
            
            log_success "Docker installed and configured as systemd service"
        fi
    fi
} || {
    log_error "Docker installation failed"
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
    # Check if registry is already running
    if docker ps | grep -q "local-registry"; then
        log_info "Local registry is already running"
    else
        # Start local registry
        docker run -d -p ${REGISTRY_PORT}:${REGISTRY_PORT} --name local-registry registry:2
        
        # Wait for registry to be ready
        sleep 10
    fi
    
    # Test registry
    curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog || {
        log_error "Registry not responding"
        exit 1
    }
    
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

# Step 13: Deploy AIM Engine
log_info "Step 13: Deploying AIM Engine..."
{
    # Change to helm directory
    cd /root/aim-engine/k8s/helm
    
    # Clean up any existing resources that might conflict
    log_info "Cleaning up any conflicting resources..."
    kubectl delete serviceaccount aim-engine-sa -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    kubectl delete pvc aim-engine-pvc -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    kubectl delete service aim-engine-service -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    kubectl delete deployment aim-engine -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    
    # Wait a moment for cleanup
    sleep 5
    
    # Try Helm deployment first
    log_info "Attempting Helm deployment..."
    if helm install aim-engine . \
        --namespace ${AIM_ENGINE_NAMESPACE} \
        --set image.repository=localhost:${REGISTRY_PORT}/aim-vllm \
        --set image.tag=latest \
        --set image.pullPolicy=IfNotPresent \
        --set aim_engine.recipe.auto_select=false \
        --set aim_engine.recipe.gpu_count=1 \
        --set aim_engine.recipe.model_id="Qwen/Qwen2.5-7B-Instruct" \
        --set aim_engine.recipe.precision=bfloat16 \
        --set resources.limits.memory=32Gi \
        --set resources.requests.memory=16Gi \
        --set livenessProbe.enabled=false \
        --set readinessProbe.enabled=false \
        --set service.type=NodePort \
        --set service.port=8000 \
        --set service.targetPort=8000; then
        
        log_success "AIM Engine deployed via Helm"
    else
        log_warning "Helm deployment failed, using manual deployment..."
        
        # Create resources manually for fallback
        log_info "Creating resources manually..."
        
        # Create ServiceAccount
        kubectl create serviceaccount aim-engine-sa -n ${AIM_ENGINE_NAMESPACE}
        
        # Create PVC
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aim-engine-pvc
  namespace: ${AIM_ENGINE_NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: local-path
EOF
        
        # Create Service
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: aim-engine-service
  namespace: ${AIM_ENGINE_NAMESPACE}
spec:
  type: NodePort
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: aim-engine
    app.kubernetes.io/instance: aim-engine
EOF
        
        # Use manual deployment as fallback
        kubectl apply -f /root/aim-engine/k8s/aim-engine-deployment.yaml
        
        # Ensure deployment is scaled to 1
        kubectl scale deployment aim-engine -n ${AIM_ENGINE_NAMESPACE} --replicas=1
        
        log_success "AIM Engine deployed manually"
    fi
    
} || {
    log_error "AIM Engine deployment failed"
    exit 1
}

# Step 14: Wait for deployment and verify
log_info "Step 14: Waiting for deployment to be ready..."
{
    # Wait for PVC to be bound
    kubectl wait --for=condition=bound pvc -l app.kubernetes.io/name=aim-engine -n ${AIM_ENGINE_NAMESPACE} --timeout=300s
    
    # Ensure deployment exists and is scaled to 1
    if ! kubectl get deployment aim-engine -n ${AIM_ENGINE_NAMESPACE} >/dev/null 2>&1; then
        log_warning "Deployment not found, creating it..."
        kubectl apply -f /root/aim-engine/k8s/aim-engine-deployment.yaml
    fi
    
    # Scale deployment to 1 if needed
    kubectl scale deployment aim-engine -n ${AIM_ENGINE_NAMESPACE} --replicas=1
    
    # Wait for pod to be ready with retries
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aim-engine -n ${AIM_ENGINE_NAMESPACE} --timeout=600s; then
            break
        else
            retry_count=$((retry_count + 1))
            log_warning "Pod not ready, retry $retry_count/$max_retries"
            
            # Check if there are any issues with the pod
            local pod_name=$(kubectl get pods -n ${AIM_ENGINE_NAMESPACE} -l app.kubernetes.io/name=aim-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            if [[ -n "$pod_name" ]]; then
                log_info "Pod status:"
                kubectl describe pod $pod_name -n ${AIM_ENGINE_NAMESPACE} | tail -20
            fi
            
            # Wait a bit before retrying
            sleep 30
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log_error "Pod failed to become ready after $max_retries retries"
        exit 1
    fi
    
    # Get service details
    NODEPORT=$(kubectl get svc -n ${AIM_ENGINE_NAMESPACE} aim-engine-service -o jsonpath='{.spec.ports[0].nodePort}')
    NODE_IP=$(hostname -I | awk '{print $1}')
    
    log_success "AIM Engine is ready!"
    log_info "Access your AIM Engine at: http://${NODE_IP}:${NODEPORT}"
    log_info "Health check: curl http://${NODE_IP}:${NODEPORT}/health"
    log_info "Models: curl http://${NODE_IP}:${NODEPORT}/v1/models"
    
    # Verify the service is actually working
    log_info "Verifying service is working..."
    sleep 10  # Give the service a moment to be ready
    
    if curl -s http://${NODE_IP}:${NODEPORT}/health > /dev/null; then
        log_success "Health check passed!"
    else
        log_warning "Health check failed, but deployment may still be starting up"
    fi
    
} || {
    log_error "Deployment verification failed"
    exit 1
}

# Final success message
log_success "🎉 AIM Engine Kubernetes setup completed successfully!"
log_info "Your cluster is ready with:"
log_info "  - Kubernetes v${KUBERNETES_VERSION}"
log_info "  - AMD GPU support"
log_info "  - Local container registry"
log_info "  - AIM Engine with Qwen/Qwen2.5-7B-Instruct"
log_info "  - NodePort service for external access"

# Display useful commands
echo ""
log_info "Useful commands:"
echo "  kubectl get pods -n ${AIM_ENGINE_NAMESPACE}"
echo "  kubectl logs -f -n ${AIM_ENGINE_NAMESPACE} -l app.kubernetes.io/name=aim-engine"
echo "  kubectl get svc -n ${AIM_ENGINE_NAMESPACE}"
echo "  curl http://${NODE_IP}:${NODEPORT}/health"
echo "  curl http://${NODE_IP}:${NODEPORT}/v1/models"
echo "" 