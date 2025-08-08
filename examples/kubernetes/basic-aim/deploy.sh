#!/bin/bash

# Basic AIM Deployment Script
# This script deploys a basic AIM instance using the AIM Engine operator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Configuration
NAMESPACE="aim-engine"
AIM_NAME="basic-aim"

log_info "🚀 Deploying Basic AIM Example"

# Check if AIM Engine operator is running
log_info "Checking AIM Engine operator status..."
if ! kubectl get pods -n aim-engine-system | grep -q "Running"; then
    log_error "AIM Engine operator is not running. Please deploy it first:"
    log_error "cd k8s/operator && ./scripts/setup-and-test-operator.sh"
    exit 1
fi

log_success "AIM Engine operator is running"

# Create namespace if it doesn't exist
log_info "Creating namespace if needed..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Deploy AIM recipe
log_info "Deploying AIM recipe..."
kubectl apply -f aimrecipe.yaml

# Wait for recipe to be ready
log_info "Waiting for AIM recipe to be ready..."
kubectl wait --for=condition=ready aimrecipe qwen-7b-basic -n ${NAMESPACE} --timeout=60s

# Deploy AIM endpoint
log_info "Deploying AIM endpoint..."
kubectl apply -f aimendpoint.yaml

# Wait for AIM to be ready
log_info "Waiting for AIM to be ready..."
kubectl wait --for=condition=ready aimendpoint ${AIM_NAME} -n ${NAMESPACE} --timeout=300s

# Check AIM status
log_info "Checking AIM status..."
kubectl get aimendpoint ${AIM_NAME} -n ${NAMESPACE}

# Get service information
log_info "Getting service information..."
kubectl get svc ${AIM_NAME} -n ${NAMESPACE}

# Check pod status
log_info "Checking pod status..."
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=aim-endpoint

log_success "🎉 Basic AIM deployed successfully!"
echo ""
log_info "Next steps:"
echo "1. Set up port forwarding:"
echo "   kubectl port-forward svc/${AIM_NAME} 8000:8000 -n ${NAMESPACE}"
echo ""
echo "2. Run the client:"
echo "   python3 client.py"
echo ""
echo "3. Check AIM logs:"
echo "   kubectl logs -f deployment/${AIM_NAME} -n ${NAMESPACE}"
echo ""
echo "4. Monitor AIM status:"
echo "   kubectl get aimendpoint ${AIM_NAME} -n ${NAMESPACE} -w" 