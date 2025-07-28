#!/bin/bash

# AIM Engine Operator Deployment Script
# This script builds and deploys the AIM Engine operator to a Kubernetes cluster

set -e

# Configuration
OPERATOR_NAMESPACE="aim-engine-operator"
REGISTRY_PORT="5000"
OPERATOR_IMAGE="localhost:${REGISTRY_PORT}/aim-engine-operator:latest"

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
    
    log_success "Kubernetes cluster connection verified"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Cannot connect to Docker daemon"
        exit 1
    fi
    
    log_success "Docker connection verified"
}

# Check if local registry is running
check_registry() {
    if ! docker ps --format "table {{.Names}}" | grep -q "local-registry"; then
        log_warning "Local registry not found, starting it..."
        docker run -d -p ${REGISTRY_PORT}:${REGISTRY_PORT} --name local-registry registry:2
        sleep 5
    fi
    
    if ! curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog &> /dev/null; then
        log_error "Local registry is not responding"
        exit 1
    fi
    
    log_success "Local registry is running"
}

# Build the operator
build_operator() {
    log_info "Building AIM Engine operator..."
    
    # Change to operator directory
    cd k8s/operator
    
    # Build the operator image
    docker build -t ${OPERATOR_IMAGE} .
    
    # Push to local registry
    docker push ${OPERATOR_IMAGE}
    
    log_success "Operator built and pushed to local registry"
}

# Deploy the operator
deploy_operator() {
    log_info "Deploying AIM Engine operator..."
    
    # Create namespace
    kubectl create namespace ${OPERATOR_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply CRDs
    kubectl apply -f config/crd/bases/
    
    # Apply RBAC
    kubectl apply -f config/rbac/
    
    # Apply manager deployment
    kubectl apply -f config/manager/
    
    # Wait for operator to be ready
    log_info "Waiting for operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/aim-engine-operator-controller-manager -n ${OPERATOR_NAMESPACE}
    
    log_success "Operator deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check operator pod
    if kubectl get pods -n ${OPERATOR_NAMESPACE} | grep -q "Running"; then
        log_success "Operator pod is running"
    else
        log_error "Operator pod is not running"
        kubectl get pods -n ${OPERATOR_NAMESPACE}
        exit 1
    fi
    
    # Check CRDs
    if kubectl get crd | grep -q "aimendpoints.aim.engine.amd.com"; then
        log_success "AIMEndpoint CRD is installed"
    else
        log_error "AIMEndpoint CRD is not installed"
        exit 1
    fi
    
    if kubectl get crd | grep -q "aimrecipes.aim.engine.amd.com"; then
        log_success "AIMRecipe CRD is installed"
    else
        log_error "AIMRecipe CRD is not installed"
        exit 1
    fi
    
    if kubectl get crd | grep -q "aimcaches.aim.engine.amd.com"; then
        log_success "AIMCache CRD is installed"
    else
        log_error "AIMCache CRD is not installed"
        exit 1
    fi
    
    log_success "Deployment verification completed"
}

# Test the operator
test_operator() {
    log_info "Testing operator with example resources..."
    
    # Create test namespace
    kubectl create namespace aim-engine --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply example resources
    kubectl apply -f examples/aimrecipe.yaml
    kubectl apply -f examples/aimcache.yaml
    kubectl apply -f examples/aimendpoint.yaml
    
    # Wait for endpoint to be ready
    log_info "Waiting for endpoint to be ready..."
    kubectl wait --for=condition=ready --timeout=600s aimendpoint/qwen-7b-demo -n aim-engine
    
    # Check endpoint status
    kubectl get aimendpoints -n aim-engine
    kubectl describe aimendpoint qwen-7b-demo -n aim-engine
    
    log_success "Operator test completed"
}

# Cleanup test resources
cleanup_test() {
    log_info "Cleaning up test resources..."
    
    kubectl delete -f examples/aimendpoint.yaml --ignore-not-found=true
    kubectl delete -f examples/aimcache.yaml --ignore-not-found=true
    kubectl delete -f examples/aimrecipe.yaml --ignore-not-found=true
    
    log_success "Test resources cleaned up"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build-only      Only build the operator image"
    echo "  --deploy-only     Only deploy the operator (assumes image exists)"
    echo "  --test            Run tests after deployment"
    echo "  --cleanup         Clean up test resources"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Full deployment"
    echo "  $0 --build-only   # Only build image"
    echo "  $0 --test         # Deploy and test"
    echo "  $0 --cleanup      # Clean up tests"
}

# Main function
main() {
    local build_only=false
    local deploy_only=false
    local run_test=false
    local cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                build_only=true
                shift
                ;;
            --deploy-only)
                deploy_only=true
                shift
                ;;
            --test)
                run_test=true
                shift
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_kubectl
    check_docker
    check_registry
    
    # Handle cleanup
    if [[ "$cleanup" == "true" ]]; then
        cleanup_test
        exit 0
    fi
    
    # Build operator
    if [[ "$deploy_only" != "true" ]]; then
        build_operator
    fi
    
    # Deploy operator
    if [[ "$build_only" != "true" ]]; then
        deploy_operator
        verify_deployment
        
        # Run tests if requested
        if [[ "$run_test" == "true" ]]; then
            test_operator
        fi
    fi
    
    log_success "AIM Engine operator deployment completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "1. Create AIMEndpoint resources: kubectl apply -f examples/aimendpoint.yaml"
    echo "2. Check status: kubectl get aimendpoints -n aim-engine"
    echo "3. View logs: kubectl logs -f deployment/aim-engine-operator-controller-manager -n ${OPERATOR_NAMESPACE}"
    echo "4. Run tests: $0 --test"
    echo "5. Cleanup: $0 --cleanup"
}

# Run main function
main "$@" 