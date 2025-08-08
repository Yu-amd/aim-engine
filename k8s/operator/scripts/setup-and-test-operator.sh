#!/bin/bash

# AIM Engine Operator Setup and Test Script
# For fresh remote nodes with AMD GPUs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
OPERATOR_NAMESPACE="aim-engine-system"
TEST_NAMESPACE="aim-engine"
OPERATOR_IMAGE="localhost:5000/aim-engine-operator:latest"

log_info "🚀 Starting AIM Engine Operator Setup and Test on Fresh Remote Node"

# Step 1: Check prerequisites
log_step "Step 1: Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

if ! command -v go &> /dev/null; then
    log_warning "Go is not installed. Installing Go..."
    apt update && apt install -y golang-go
fi

log_success "Prerequisites check completed"

# Step 2: Setup Kubernetes cluster
log_step "Step 2: Setting up Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
    log_warning "Kubernetes cluster not detected. Running cluster setup..."
    
    # Run the complete Kubernetes setup script
    cd ../../
    chmod +x k8s/scripts/setup-complete-kubernetes.sh
    ./k8s/scripts/setup-complete-kubernetes.sh
    
    # Return to operator directory
    cd k8s/operator
else
    log_success "Kubernetes cluster is already running"
fi

# Step 3: Verify cluster status
log_step "Step 3: Verifying cluster status..."
kubectl get nodes
kubectl get pods --all-namespaces

# Step 4: Setup local registry
log_step "Step 4: Setting up local Docker registry..."
if ! docker ps | grep -q "registry"; then
    log_info "Starting local Docker registry..."
    docker run -d --name registry -p 5000:5000 --restart=always registry:2
    sleep 5
else
    log_success "Local registry is already running"
fi

# Step 5: Build and deploy operator
log_step "Step 5: Building and deploying the operator..."

# Build the operator binary
log_info "Building operator binary..."
go build -o manager cmd/operator/main.go
if [ $? -eq 0 ]; then
    log_success "Operator binary built successfully"
else
    log_error "Failed to build operator binary"
    exit 1
fi

# Build the Docker image
log_info "Building operator Docker image..."
docker build -t ${OPERATOR_IMAGE} .
if [ $? -eq 0 ]; then
    log_success "Operator Docker image built successfully"
else
    log_error "Failed to build operator Docker image"
    exit 1
fi

# Push to local registry
log_info "Pushing operator image to local registry..."
docker push ${OPERATOR_IMAGE}
if [ $? -eq 0 ]; then
    log_success "Operator image pushed to local registry"
else
    log_error "Failed to push operator image to local registry"
    exit 1
fi

# Step 6: Deploy operator to Kubernetes
log_step "Step 6: Deploying operator to Kubernetes..."

# Create namespace
log_info "Creating operator namespace..."
kubectl create namespace ${OPERATOR_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install CRDs
log_info "Installing Custom Resource Definitions..."
kubectl apply -f config/crd/bases/

# Install RBAC
log_info "Installing RBAC resources..."
kubectl apply -f config/rbac/

# Deploy the operator
log_info "Deploying the operator..."
kubectl apply -f config/manager/

# Wait for operator to be ready
log_info "Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n ${OPERATOR_NAMESPACE} --timeout=300s

if [ $? -eq 0 ]; then
    log_success "Operator deployed successfully!"
else
    log_error "Operator deployment failed"
    kubectl describe pods -n ${OPERATOR_NAMESPACE}
    kubectl logs -n ${OPERATOR_NAMESPACE} -l control-plane=controller-manager --tail=50
    exit 1
fi

# Step 7: Verify operator status
log_step "Step 7: Verifying operator status..."
kubectl get pods -n ${OPERATOR_NAMESPACE}
kubectl get crd | grep aim.engine.amd.com

# Step 8: Run comprehensive tests
log_step "Step 8: Running comprehensive operator tests..."
chmod +x scripts/test-operator.sh
./scripts/test-operator.sh

if [ $? -eq 0 ]; then
    log_success "🎉 All tests passed! Operator is working correctly."
else
    log_error "❌ Some tests failed. Check the output above for details."
    exit 1
fi

# Step 9: Show final status
log_step "Step 9: Final status report..."
echo ""
log_info "=== OPERATOR STATUS ==="
kubectl get pods -n ${OPERATOR_NAMESPACE}
echo ""
log_info "=== CUSTOM RESOURCES ==="
kubectl get aimendpoint -n ${TEST_NAMESPACE} 2>/dev/null || echo "No AIMEndpoints found"
kubectl get aimrecipe -n ${TEST_NAMESPACE} 2>/dev/null || echo "No AIMRecipes found"
kubectl get aimcache -n ${TEST_NAMESPACE} 2>/dev/null || echo "No AIMCaches found"
echo ""
log_info "=== OPERATOR LOGS (last 10 lines) ==="
kubectl logs -n ${OPERATOR_NAMESPACE} -l control-plane=controller-manager --tail=10

# Step 10: Provide next steps
log_step "Step 10: Next steps for testing..."
echo ""
log_info "🎯 Your AIM Engine Operator is now ready!"
log_info ""
log_info "To test custom resources manually:"
log_info "  kubectl apply -f examples/aimrecipe.yaml"
log_info "  kubectl apply -f examples/aimendpoint.yaml"
log_info "  kubectl get aimendpoint -n ${TEST_NAMESPACE}"
log_info ""
log_info "To monitor operator logs:"
log_info "  kubectl logs -f -n ${OPERATOR_NAMESPACE} -l control-plane=controller-manager"
log_info ""
log_info "To check operator metrics:"
log_info "  kubectl port-forward -n ${OPERATOR_NAMESPACE} svc/aim-engine-operator-controller-manager-metrics-service 8080:8080"
log_info ""
log_success "🚀 Setup and testing completed successfully!" 