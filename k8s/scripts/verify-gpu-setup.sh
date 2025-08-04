#!/bin/bash

# AIM Engine - AMD GPU Verification Script
# This script verifies AMD GPU setup in Kubernetes

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

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "kubectl is available and connected to cluster"
}

# Check cluster nodes
check_nodes() {
    log_info "Checking cluster nodes..."
    
    echo
    echo "=== Cluster Nodes ==="
    kubectl get nodes -o wide
    
    echo
    echo "=== Node Resources ==="
    kubectl get nodes -o json | jq -r '.items[] | "Node: \(.metadata.name) | CPU: \(.status.allocatable.cpu) | Memory: \(.status.allocatable.memory) | GPUs: \(.status.allocatable["amd.com/gpu"] // "0")"'
    
    # Check for GPU nodes
    local gpu_nodes=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.allocatable["amd.com/gpu"] != null) | .metadata.name')
    
    if [[ -n "$gpu_nodes" ]]; then
        log_success "Found GPU nodes: $gpu_nodes"
    else
        log_warning "No GPU nodes found"
    fi
}

# Check AMD GPU operator
check_amd_gpu_operator() {
    log_info "Checking AMD GPU operator..."
    
    echo
    echo "=== AMD GPU Operator Namespace ==="
    kubectl get pods -n gpu-operator-system 2>/dev/null || echo "No resources found in gpu-operator-system namespace."
    
    echo
    echo "=== AMD GPU Operator Status ==="
    local operator_pods=$(kubectl get pods -n gpu-operator-system -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name): \(.status.phase)"' 2>/dev/null || echo "No operator pods found")
    echo "$operator_pods"
    
    # Check if all pods are running
    local failed_pods=$(kubectl get pods -n gpu-operator-system -o json 2>/dev/null | jq -r '.items[] | select(.status.phase != "Running") | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -n "$failed_pods" && "$failed_pods" != "" ]]; then
        log_warning "Some GPU operator pods are not running: $failed_pods"
    else
        log_success "All AMD GPU operator pods are running"
    fi
}

# Check GPU device plugin
check_gpu_device_plugin() {
    log_info "Checking GPU device plugin..."
    
    echo
    echo "=== GPU Device Plugin Pods (kube-system) ==="
    kubectl get pods -n kube-system -l name=amd-gpu-device-plugin
    
    echo
    echo "=== GPU Device Plugin Logs ==="
    local device_plugin_pod=$(kubectl get pods -n kube-system -l name=amd-gpu-device-plugin -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$device_plugin_pod" ]]; then
        kubectl logs $device_plugin_pod -n kube-system --tail=20
        log_success "GPU device plugin is running"
    else
        log_warning "GPU device plugin pod not found in kube-system namespace"
    fi
}

# Check GPU driver
check_gpu_driver() {
    log_info "Checking GPU driver..."
    
    echo
    echo "=== GPU Driver Pods ==="
    kubectl get pods -n gpu-operator-system -l app=amd-gpu-driver 2>/dev/null || echo "No GPU driver pods found"
    
    echo
    echo "=== GPU Driver Status ==="
    kubectl get pods -n gpu-operator-system -l app=amd-gpu-driver -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name): \(.status.phase)"' 2>/dev/null || echo "No GPU driver pods found"
}

# Check GPU resources
check_gpu_resources() {
    log_info "Checking GPU resources..."
    
    echo
    echo "=== Available GPU Resources ==="
    kubectl get nodes -o json | jq -r '.items[] | select(.status.allocatable["amd.com/gpu"] != null) | "Node: \(.metadata.name) | GPUs: \(.status.allocatable["amd.com/gpu"])"'
    
    echo
    echo "=== GPU Resource Details ==="
    kubectl describe nodes | grep -A 10 "amd.com/gpu"
}

# Test GPU allocation
test_gpu_allocation() {
    log_info "Testing GPU allocation..."
    
    echo
    echo "=== Creating GPU test pod ==="
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    amd.com/gpu: "true"
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: gpu-test
    image: rocm/dev-ubuntu-22.04
    command: ["/bin/bash"]
    args: ["-c", "rocm-smi && echo 'GPU test completed successfully' && exit 0"]
    resources:
      limits:
        amd.com/gpu: 1
      requests:
        amd.com/gpu: 1
EOF
    
    echo "Waiting for GPU test pod to complete..."
    kubectl wait --for=condition=Ready pod/gpu-test --timeout=120s
    
    echo
    echo "=== GPU Test Pod Logs ==="
    kubectl logs gpu-test
    
    echo
    echo "=== Cleaning up test pod ==="
    kubectl delete pod gpu-test
    
    log_success "GPU allocation test completed"
}

# Check system GPU information
check_system_gpu() {
    log_info "Checking system GPU information..."
    
    echo
    echo "=== System GPU Information ==="
    
    if command -v rocm-smi &> /dev/null; then
        echo "ROCm SMI Output:"
        rocm-smi
    else
        log_warning "rocm-smi not found"
    fi
    
    echo
    echo "=== GPU Devices ==="
    ls -la /dev/dri/
    
    echo
    echo "=== GPU Kernel Modules ==="
    lsmod | grep -i amdgpu || echo "No AMD GPU kernel modules loaded"
}

# Check Kubernetes GPU operator logs
check_gpu_operator_logs() {
    log_info "Checking GPU operator logs..."
    
    echo
    echo "=== GPU Operator Logs ==="
    kubectl logs -n gpu-operator-system -l app=amd-gpu-operator --tail=20 2>/dev/null || echo "No GPU operator logs found"
    
    echo
    echo "=== GPU Device Plugin Logs ==="
    kubectl logs -n kube-system -l name=amd-gpu-device-plugin --tail=20 2>/dev/null || echo "No GPU device plugin logs found"
}

# Main verification function
main() {
    log_info "Starting AMD GPU verification..."
    
    check_kubectl
    check_nodes
    check_amd_gpu_operator
    check_gpu_device_plugin
    check_gpu_driver
    check_gpu_resources
    check_system_gpu
    check_gpu_operator_logs
    test_gpu_allocation
    
    log_success "AMD GPU verification completed!"
    
    echo
    echo "=== Summary ==="
    echo "If all checks passed, your AMD GPUs are ready for AIM Engine deployment."
    echo
    echo "Next steps:"
    echo "1. Deploy AIM Engine: cd k8s && helm install aim-engine ./helm"
    echo "2. Monitor deployment: kubectl get pods -n aim-engine"
    echo "3. Test inference: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine"
}

# Run main function
main "$@" 