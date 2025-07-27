#!/bin/bash

# AIM Engine Kubernetes Cleanup Script
# This script removes all AIM Engine resources from Kubernetes cluster

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
AIM_ENGINE_NAMESPACE="aim-engine"
REGISTRY_PORT="5000"

# Parse command line arguments
CLEANUP_ALL=false
CLEANUP_IMAGES=false
CLEANUP_REGISTRY=false
CLEANUP_CLUSTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEANUP_ALL=true
            shift
            ;;
        --images)
            CLEANUP_IMAGES=true
            shift
            ;;
        --registry)
            CLEANUP_REGISTRY=true
            shift
            ;;
        --cluster)
            CLEANUP_CLUSTER=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --all       Clean up everything (Kubernetes + Docker + Registry)"
            echo "  --images    Remove AIM Engine Docker images"
            echo "  --registry  Stop and remove local registry"
            echo "  --cluster   Remove entire Kubernetes cluster"
            echo "  --help      Show this help message"
            echo ""
            echo "Default behavior: Remove only AIM Engine Kubernetes resources"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Starting AIM Engine cleanup..."

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl not found, skipping Kubernetes cleanup"
        return 1
    fi
    return 0
}

# Function to check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_warning "helm not found, skipping Helm cleanup"
        return 1
    fi
    return 0
}

# Function to check if docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_warning "docker not found, skipping Docker cleanup"
        return 1
    fi
    return 0
}

# Step 1: Clean up Kubernetes resources
cleanup_kubernetes() {
    log_info "Step 1: Cleaning up Kubernetes resources..."
    
    if ! check_kubectl; then
        return
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_warning "Cannot connect to Kubernetes cluster, skipping Kubernetes cleanup"
        return
    fi
    
    # Remove AIM Engine Helm release
    if check_helm; then
        if helm list -n ${AIM_ENGINE_NAMESPACE} | grep -q "aim-engine"; then
            log_info "Removing AIM Engine Helm release..."
            helm uninstall aim-engine -n ${AIM_ENGINE_NAMESPACE} || {
                log_warning "Failed to uninstall Helm release, trying force removal..."
                kubectl delete deployment aim-engine -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
                kubectl delete service aim-engine-service -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
                kubectl delete pvc aim-engine-pvc -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
                kubectl delete serviceaccount aim-engine -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
            }
        else
            log_info "No AIM Engine Helm release found"
        fi
    fi
    
    # Remove any remaining pods
    log_info "Removing any remaining pods..."
    kubectl delete pods -l app.kubernetes.io/name=aim-engine -n ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    
    # Remove namespace
    log_info "Removing AIM Engine namespace..."
    kubectl delete namespace ${AIM_ENGINE_NAMESPACE} --ignore-not-found=true
    
    # Wait for namespace deletion
    if kubectl get namespace ${AIM_ENGINE_NAMESPACE} > /dev/null 2>&1; then
        log_info "Waiting for namespace deletion..."
        kubectl wait --for=delete namespace/${AIM_ENGINE_NAMESPACE} --timeout=60s || {
            log_warning "Namespace deletion timeout, forcing removal..."
            kubectl patch namespace ${AIM_ENGINE_NAMESPACE} -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        }
    fi
    
    log_success "Kubernetes resources cleaned up"
}

# Step 2: Clean up Docker images
cleanup_images() {
    log_info "Step 2: Cleaning up Docker images..."
    
    if ! check_docker; then
        return
    fi
    
    # Remove AIM Engine images
    log_info "Removing AIM Engine Docker images..."
    
    # Remove images from local registry
    docker rmi localhost:${REGISTRY_PORT}/aim-vllm:latest --force 2>/dev/null || true
    
    # Remove local images
    docker rmi aim-vllm:latest --force 2>/dev/null || true
    
    # Remove any dangling images
    log_info "Removing dangling images..."
    docker image prune -f
    
    log_success "Docker images cleaned up"
}

# Step 3: Clean up local registry
cleanup_registry() {
    log_info "Step 3: Cleaning up local registry..."
    
    if ! check_docker; then
        return
    fi
    
    # Stop and remove local registry container
    if docker ps | grep -q "local-registry"; then
        log_info "Stopping local registry..."
        docker stop local-registry || true
        docker rm local-registry || true
    fi
    
    # Remove registry image if requested
    if [[ "$CLEANUP_ALL" == "true" || "$CLEANUP_REGISTRY" == "true" ]]; then
        log_info "Removing registry image..."
        docker rmi registry:2 --force 2>/dev/null || true
    fi
    
    log_success "Local registry cleaned up"
}

# Step 4: Clean up entire cluster (if requested)
cleanup_cluster() {
    if [[ "$CLEANUP_ALL" == "true" || "$CLEANUP_CLUSTER" == "true" ]]; then
        log_warning "Step 4: Cleaning up entire Kubernetes cluster..."
        
        if ! check_kubectl; then
            return
        fi
        
        # Check if cluster is accessible
        if ! kubectl cluster-info > /dev/null 2>&1; then
            log_warning "Cannot connect to Kubernetes cluster"
            return
        fi
        
        # Drain the node
        log_info "Draining node..."
        kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data --force || true
        
        # Reset kubeadm
        log_info "Resetting kubeadm..."
        kubeadm reset --force || true
        
        # Remove kubeconfig files
        log_info "Removing kubeconfig files..."
        rm -rf $HOME/.kube
        rm -rf /home/*/.kube 2>/dev/null || true
        
        # Remove containerd data
        log_info "Cleaning containerd data..."
        rm -rf /var/lib/containerd/io.containerd.grpc.v1.cri/sandboxes/* 2>/dev/null || true
        rm -rf /var/lib/containerd/io.containerd.grpc.v1.cri/containers/* 2>/dev/null || true
        
        # Restart containerd
        log_info "Restarting containerd..."
        systemctl restart containerd || true
        
        log_success "Kubernetes cluster cleaned up"
    fi
}

# Step 5: Clean up system resources
cleanup_system() {
    if [[ "$CLEANUP_ALL" == "true" ]]; then
        log_info "Step 5: Cleaning up system resources..."
        
        # Remove any remaining containers
        log_info "Removing all containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        # Remove all images
        log_info "Removing all Docker images..."
        docker rmi $(docker images -aq) --force 2>/dev/null || true
        
        # Clean up Docker system
        log_info "Cleaning Docker system..."
        docker system prune -af || true
        
        # Clean up any remaining volumes
        log_info "Cleaning Docker volumes..."
        docker volume prune -f || true
        
        # Clean up networks
        log_info "Cleaning Docker networks..."
        docker network prune -f || true
        
        log_success "System resources cleaned up"
    fi
}

# Main execution
main() {
    # Default cleanup (Kubernetes resources only)
    if [[ "$CLEANUP_ALL" == "false" && "$CLEANUP_IMAGES" == "false" && "$CLEANUP_REGISTRY" == "false" && "$CLEANUP_CLUSTER" == "false" ]]; then
        cleanup_kubernetes
        return
    fi
    
    # Specific cleanup based on flags
    if [[ "$CLEANUP_IMAGES" == "true" ]]; then
        cleanup_images
    fi
    
    if [[ "$CLEANUP_REGISTRY" == "true" ]]; then
        cleanup_registry
    fi
    
    if [[ "$CLEANUP_CLUSTER" == "true" ]]; then
        cleanup_cluster
    fi
    
    # Full cleanup
    if [[ "$CLEANUP_ALL" == "true" ]]; then
        cleanup_kubernetes
        cleanup_images
        cleanup_registry
        cleanup_cluster
        cleanup_system
    fi
}

# Run main function
main "$@"

# Final success message
log_success "🎉 AIM Engine cleanup completed!"
echo ""
log_info "Cleanup summary:"
if [[ "$CLEANUP_ALL" == "true" ]]; then
    echo "  ✅ Complete cleanup (Kubernetes + Docker + Registry + System)"
elif [[ "$CLEANUP_CLUSTER" == "true" ]]; then
    echo "  ✅ Kubernetes cluster removed"
elif [[ "$CLEANUP_IMAGES" == "true" || "$CLEANUP_REGISTRY" == "true" ]]; then
    echo "  ✅ Selected resources cleaned up"
else
    echo "  ✅ AIM Engine Kubernetes resources removed"
fi
echo "" 