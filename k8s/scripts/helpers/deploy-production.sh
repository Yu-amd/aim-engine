#!/bin/bash

# AIM Engine Kubernetes Deployment Script
# This script deploys the AIM Engine to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="aim-engine"
ENVIRONMENT="${1:-development}"
REGISTRY="${2:-localhost:5000}"
IMAGE_TAG="${3:-latest}"
IMAGE_NAME="aim-vllm"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "kubectl is available and connected to cluster"
}

# Function to check if kustomize is available
check_kustomize() {
    if ! command -v kustomize &> /dev/null; then
        print_warning "kustomize is not installed. Installing..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
    fi
    
    print_success "kustomize is available"
}

# Function to build and push Docker image
build_image() {
    print_status "Building Docker image..."
    
    if [ ! -f "Dockerfile.aim-vllm" ]; then
        print_error "Dockerfile.aim-vllm not found"
        exit 1
    fi
    
    docker build -f Dockerfile.aim-vllm -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
    
    if [ "$REGISTRY" != "localhost:5000" ]; then
        print_status "Pushing image to registry..."
        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    fi
    
    print_success "Image built and pushed successfully"
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace..."
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace created"
}

# Function to deploy with kustomize
deploy_with_kustomize() {
    print_status "Deploying with kustomize..."
    
    cd k8s
    
    # Update image in kustomization
    kustomize edit set image ${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    
    # Apply the configuration
    kustomize build . | kubectl apply -f -
    
    cd ..
    
    print_success "Deployment completed"
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/aim-engine -n ${NAMESPACE}
    
    print_success "Deployment is ready"
}

# Function to show deployment status
show_status() {
    print_status "Deployment status:"
    echo ""
    kubectl get pods -n ${NAMESPACE}
    echo ""
    kubectl get services -n ${NAMESPACE}
    echo ""
    kubectl get ingress -n ${NAMESPACE}
}

# Function to show logs
show_logs() {
    print_status "Recent logs from AIM Engine pods:"
    echo ""
    kubectl logs -n ${NAMESPACE} -l app=aim-engine --tail=50
}

# Function to clean up
cleanup() {
    print_status "Cleaning up..."
    cd k8s
    kustomize build . | kubectl delete -f - --ignore-not-found=true
    cd ..
    print_success "Cleanup completed"
}

# Main deployment function
deploy() {
    print_status "Starting AIM Engine deployment..."
    print_status "Environment: ${ENVIRONMENT}"
    print_status "Registry: ${REGISTRY}"
    print_status "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Pre-flight checks
    check_kubectl
    check_kustomize
    
    # Build and push image
    build_image
    
    # Create namespace
    create_namespace
    
    # Deploy
    deploy_with_kustomize
    
    # Wait for deployment
    wait_for_deployment
    
    # Show status
    show_status
    
    print_success "AIM Engine deployment completed successfully!"
    print_status "You can access the service at:"
    kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].spec.rules[0].host}'
}

# Function to show usage
usage() {
    echo "Usage: $0 [environment] [registry] [image-tag]"
    echo ""
    echo "Arguments:"
    echo "  environment   Deployment environment (development|production) [default: development]"
    echo "  registry      Docker registry URL [default: localhost:5000]"
    echo "  image-tag     Docker image tag [default: latest]"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy development environment"
    echo "  $0 production                         # Deploy production environment"
    echo "  $0 production my-registry.com v1.0.0 # Deploy with custom registry and tag"
    echo ""
    echo "Commands:"
    echo "  $0 status    # Show deployment status"
    echo "  $0 logs      # Show recent logs"
    echo "  $0 cleanup   # Clean up deployment"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        print_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac 