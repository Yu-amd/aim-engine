#!/bin/bash

# Basic AIM Cleanup Script
# This script removes the basic AIM example

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

log_info "🧹 Cleaning up Basic AIM Example"

# Remove AIM endpoint
log_info "Removing AIM endpoint..."
kubectl delete aimendpoint ${AIM_NAME} -n ${NAMESPACE} --ignore-not-found=true

# Wait for AIM to be deleted
log_info "Waiting for AIM to be deleted..."
kubectl wait --for=delete aimendpoint ${AIM_NAME} -n ${NAMESPACE} --timeout=60s 2>/dev/null || true

# Remove AIM recipe
log_info "Removing AIM recipe..."
kubectl delete aimrecipe qwen-7b-basic -n ${NAMESPACE} --ignore-not-found=true

# Wait for recipe to be deleted
log_info "Waiting for recipe to be deleted..."
kubectl wait --for=delete aimrecipe qwen-7b-basic -n ${NAMESPACE} --timeout=60s 2>/dev/null || true

# Check if any AIMs remain
log_info "Checking for remaining AIMs..."
REMAINING_AIMS=$(kubectl get aimendpoint -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$REMAINING_AIMS" -eq 0 ]; then
    log_info "No AIMs remaining in namespace"
else
    log_warning "There are still $REMAINING_AIMS AIM(s) in the namespace"
    kubectl get aimendpoint -n ${NAMESPACE}
fi

log_success "🎉 Basic AIM cleanup completed!" 