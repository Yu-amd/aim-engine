#!/bin/bash

# AIM Engine Deployment Script
# This script deploys AIM Engine to an existing Kubernetes cluster

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
REGISTRY_PORT="5000"
AIM_ENGINE_NAMESPACE="aim-engine"
HELM_CHART_DIR="k8s/helm"

# Default values
MODEL_ID="Qwen/Qwen2.5-7B-Instruct"
PRECISION="bfloat16"
GPU_COUNT=1
MEMORY_LIMIT="32Gi"
MEMORY_REQUEST="16Gi"
DISABLE_PROBES=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL_ID="$2"
            shift 2
            ;;
        --precision)
            PRECISION="$2"
            shift 2
            ;;
        --gpu-count)
            GPU_COUNT="$2"
            shift 2
            ;;
        --memory-limit)
            MEMORY_LIMIT="$2"
            shift 2
            ;;
        --memory-request)
            MEMORY_REQUEST="$2"
            shift 2
            ;;
        --enable-probes)
            DISABLE_PROBES=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --model MODEL_ID        Model to deploy (default: Qwen/Qwen2.5-7B-Instruct)"
            echo "  --precision PRECISION   Model precision (default: bfloat16)"
            echo "  --gpu-count COUNT       Number of GPUs (default: 1)"
            echo "  --memory-limit LIMIT    Memory limit (default: 32Gi)"
            echo "  --memory-request REQ    Memory request (default: 16Gi)"
            echo "  --enable-probes         Enable health probes (default: disabled)"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Starting AIM Engine deployment..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed"
    exit 1
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log_error "docker is not installed"
    exit 1
fi

# Step 1: Check cluster status
log_info "Step 1: Checking cluster status..."
{
    # Check if cluster is accessible
    kubectl cluster-info > /dev/null 2>&1 || {
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    }
    
    # Check if nodes are ready
    kubectl get nodes | grep -q "Ready" || {
        log_error "No ready nodes found in cluster"
        exit 1
    }
    
    log_success "Cluster is accessible and ready"
} || {
    log_error "Cluster status check failed"
    exit 1
}

# Step 2: Check GPU availability
log_info "Step 2: Checking GPU availability..."
{
    # Check if GPU resources are available
    GPU_COUNT_AVAILABLE=$(kubectl get nodes -o json | jq -r '.items[0].status.allocatable."amd.com/gpu"' 2>/dev/null || echo "0")
    
    if [[ "$GPU_COUNT_AVAILABLE" == "null" || "$GPU_COUNT_AVAILABLE" == "0" ]]; then
        log_warning "No AMD GPUs detected in cluster"
        log_info "Continuing with CPU-only deployment..."
        GPU_COUNT=0
    else
        log_success "Found ${GPU_COUNT_AVAILABLE} AMD GPU(s) available"
        
        if [[ $GPU_COUNT -gt $GPU_COUNT_AVAILABLE ]]; then
            log_warning "Requested ${GPU_COUNT} GPUs but only ${GPU_COUNT_AVAILABLE} available"
            GPU_COUNT=$GPU_COUNT_AVAILABLE
        fi
    fi
} || {
    log_error "GPU availability check failed"
    exit 1
}

# Step 3: Setup local registry
log_info "Step 3: Setting up local container registry..."
{
    # Check if registry is already running
    if ! docker ps | grep -q "local-registry"; then
        # Start local registry
        docker run -d -p ${REGISTRY_PORT}:${REGISTRY_PORT} --name local-registry registry:2
        
        # Wait for registry to be ready
        sleep 10
    fi
    
    # Test registry
    curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog > /dev/null || {
        log_error "Registry not responding"
        exit 1
    }
    
    log_success "Local container registry is ready"
} || {
    log_error "Local registry setup failed"
    exit 1
}

# Step 4: Create namespace
log_info "Step 4: Creating namespace..."
{
    kubectl create namespace ${AIM_ENGINE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespace ${AIM_ENGINE_NAMESPACE} created"
} || {
    log_error "Namespace creation failed"
    exit 1
}

# Step 5: Build and push AIM Engine image
log_info "Step 5: Building and pushing AIM Engine image..."
{
    # Change to project directory
    cd /root/aim-engine
    
    # Check if image already exists
    if ! docker images | grep -q "aim-vllm.*latest"; then
        log_info "Building AIM Engine image..."
        ./scripts/build-aim-vllm.sh
    else
        log_info "AIM Engine image already exists, skipping build"
    fi
    
    # Tag and push to local registry
    docker tag aim-vllm:latest localhost:${REGISTRY_PORT}/aim-vllm:latest
    docker push localhost:${REGISTRY_PORT}/aim-vllm:latest
    
    log_success "AIM Engine image ready in local registry"
} || {
    log_error "Image build/push failed"
    exit 1
}

# Step 6: Deploy AIM Engine
log_info "Step 6: Deploying AIM Engine..."
{
    # Change to helm directory
    cd /root/aim-engine/${HELM_CHART_DIR}
    
    # Prepare helm values
    HELM_VALUES=""
    HELM_VALUES="${HELM_VALUES} --set image.repository=localhost:${REGISTRY_PORT}/aim-vllm"
    HELM_VALUES="${HELM_VALUES} --set image.tag=latest"
    HELM_VALUES="${HELM_VALUES} --set image.pullPolicy=IfNotPresent"
    HELM_VALUES="${HELM_VALUES} --set aim_engine.recipe.auto_select=false"
    HELM_VALUES="${HELM_VALUES} --set aim_engine.recipe.model_id=\"${MODEL_ID}\""
    HELM_VALUES="${HELM_VALUES} --set aim_engine.recipe.precision=${PRECISION}"
    HELM_VALUES="${HELM_VALUES} --set resources.limits.memory=${MEMORY_LIMIT}"
    HELM_VALUES="${HELM_VALUES} --set resources.requests.memory=${MEMORY_REQUEST}"
    HELM_VALUES="${HELM_VALUES} --set service.type=NodePort"
    HELM_VALUES="${HELM_VALUES} --set service.port=8000"
    HELM_VALUES="${HELM_VALUES} --set service.targetPort=8000"
    
    if [[ $GPU_COUNT -gt 0 ]]; then
        HELM_VALUES="${HELM_VALUES} --set aim_engine.recipe.gpu_count=${GPU_COUNT}"
        HELM_VALUES="${HELM_VALUES} --set resources.limits.amd.com/gpu=${GPU_COUNT}"
        HELM_VALUES="${HELM_VALUES} --set resources.requests.amd.com/gpu=${GPU_COUNT}"
    fi
    
    if [[ "$DISABLE_PROBES" == "true" ]]; then
        HELM_VALUES="${HELM_VALUES} --set livenessProbe.enabled=false"
        HELM_VALUES="${HELM_VALUES} --set readinessProbe.enabled=false"
    fi
    
    # Check if deployment already exists
    if helm list -n ${AIM_ENGINE_NAMESPACE} | grep -q "aim-engine"; then
        log_info "Updating existing AIM Engine deployment..."
        helm upgrade aim-engine . ${HELM_VALUES} --namespace ${AIM_ENGINE_NAMESPACE}
    else
        log_info "Installing new AIM Engine deployment..."
        helm install aim-engine . ${HELM_VALUES} --namespace ${AIM_ENGINE_NAMESPACE}
    fi
    
    log_success "AIM Engine deployment completed"
} || {
    log_error "AIM Engine deployment failed"
    exit 1
}

# Step 7: Wait for deployment and verify
log_info "Step 7: Waiting for deployment to be ready..."
{
    # Wait for pod to be ready (with longer timeout for model loading)
    log_info "Waiting for pod to be ready (this may take several minutes for model loading)..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aim-engine -n ${AIM_ENGINE_NAMESPACE} --timeout=1800s
    
    # Get service details
    NODEPORT=$(kubectl get svc -n ${AIM_ENGINE_NAMESPACE} aim-engine-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    
    log_success "AIM Engine is ready!"
    log_info "Deployment details:"
    log_info "  - Model: ${MODEL_ID}"
    log_info "  - Precision: ${PRECISION}"
    log_info "  - GPUs: ${GPU_COUNT}"
    log_info "  - Memory: ${MEMORY_REQUEST} (request) / ${MEMORY_LIMIT} (limit)"
    log_info "  - NodePort: ${NODEPORT}"
    
    if [[ "$NODEPORT" != "N/A" ]]; then
        log_info "Access your AIM Engine at: http://localhost:${NODEPORT}"
        log_info "Health check: curl http://localhost:${NODEPORT}/health"
        log_info "Models: curl http://localhost:${NODEPORT}/v1/models"
    fi
    
} || {
    log_error "Deployment verification failed"
    log_info "Check pod status with: kubectl get pods -n ${AIM_ENGINE_NAMESPACE}"
    log_info "Check pod logs with: kubectl logs -n ${AIM_ENGINE_NAMESPACE} -l app.kubernetes.io/name=aim-engine"
    exit 1
}

# Final success message
log_success "🎉 AIM Engine deployment completed successfully!"
echo ""
log_info "Useful commands:"
echo "  kubectl get pods -n ${AIM_ENGINE_NAMESPACE}"
echo "  kubectl logs -f -n ${AIM_ENGINE_NAMESPACE} -l app.kubernetes.io/name=aim-engine"
echo "  kubectl get svc -n ${AIM_ENGINE_NAMESPACE}"
if [[ "$NODEPORT" != "N/A" ]]; then
    echo "  curl http://localhost:${NODEPORT}/health"
    echo "  curl http://localhost:${NODEPORT}/v1/models"
fi
echo "" 