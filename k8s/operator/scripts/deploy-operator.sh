#!/bin/bash

# AIM Engine Operator Deployment Script
# This script builds and deploys the AIM Engine operator to a Kubernetes cluster

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Configuration
OPERATOR_IMAGE="localhost:5000/aim-engine-operator:latest"
OPERATOR_NAMESPACE="aim-engine-system"

log_info "Building AIM Engine Operator..."

# Build the operator binary
log_info "Step 1: Building operator binary..."
go build -o manager cmd/operator/main.go
if [ $? -eq 0 ]; then
    log_success "Operator binary built successfully"
else
    log_error "Failed to build operator binary"
    exit 1
fi

# Build the Docker image
log_info "Step 2: Building operator Docker image..."
docker build -t ${OPERATOR_IMAGE} .
if [ $? -eq 0 ]; then
    log_success "Operator Docker image built successfully"
else
    log_error "Failed to build operator Docker image"
    exit 1
fi

# Push to local registry
log_info "Step 3: Pushing operator image to local registry..."
docker push ${OPERATOR_IMAGE}
if [ $? -eq 0 ]; then
    log_success "Operator image pushed to local registry"
else
    log_error "Failed to push operator image to local registry"
    exit 1
fi

# Create namespace
log_info "Step 4: Creating operator namespace..."
kubectl create namespace ${OPERATOR_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install CRDs
log_info "Step 5: Installing Custom Resource Definitions..."
kubectl apply -f config/crd/bases/

# Install RBAC
log_info "Step 6: Installing RBAC resources..."
kubectl apply -f config/rbac/

# Deploy the operator
log_info "Step 7: Deploying the operator..."
kubectl apply -f config/manager/

# Wait for operator to be ready
log_info "Step 8: Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n ${OPERATOR_NAMESPACE} --timeout=300s

log_success "AIM Engine Operator deployed successfully!"
log_info "Operator is running in namespace: ${OPERATOR_NAMESPACE}"
log_info "Check operator status with: kubectl get pods -n ${OPERATOR_NAMESPACE}"
log_info "Check operator logs with: kubectl logs -f -n ${OPERATOR_NAMESPACE} -l control-plane=controller-manager" 