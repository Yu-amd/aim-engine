#!/bin/bash

# AIM Engine Minikube Deployment Script
# This script deploys the AIM Engine to Minikube for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="aim-engine"

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
        print_status "Please start Minikube: minikube start"
        exit 1
    fi
    
    print_success "kubectl is available and connected to cluster"
}

# Function to check if Minikube is running
check_minikube() {
    if ! minikube status &> /dev/null; then
        print_error "Minikube is not running"
        print_status "Starting Minikube..."
        minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g
    fi
    
    print_success "Minikube is running"
}

# Function to enable Minikube addons
setup_minikube() {
    print_status "Setting up Minikube addons..."
    
    # Enable ingress addon
    minikube addons enable ingress
    
    # Enable storage provisioner
    minikube addons enable storage-provisioner
    
    print_success "Minikube addons enabled"
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace..."
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace created"
}

# Function to deploy Minikube-specific resources
deploy_minikube_resources() {
    print_status "Deploying Minikube-specific resources..."
    
    # Deploy in order
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/minikube-storage.yaml
    kubectl apply -f k8s/minikube-rbac.yaml
    kubectl apply -f k8s/minikube-deployment.yaml
    kubectl apply -f k8s/minikube-service.yaml
    
    print_success "Resources deployed"
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
    kubectl get pvc -n ${NAMESPACE}
}

# Function to show logs
show_logs() {
    print_status "Recent logs from AIM Engine pods:"
    echo ""
    kubectl logs -n ${NAMESPACE} -l app=aim-engine --tail=50
}

# Function to get service URL
get_service_url() {
    print_status "Service URLs:"
    echo ""
    echo "NodePort Service:"
    minikube service aim-engine-service -n ${NAMESPACE} --url
    echo ""
    echo "Internal Service:"
    echo "http://aim-engine-internal.${NAMESPACE}.svc.cluster.local:8000"
    echo ""
    echo "To access the service:"
    echo "minikube service aim-engine-service -n ${NAMESPACE}"
}

# Function to clean up
cleanup() {
    print_status "Cleaning up..."
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    print_success "Cleanup completed"
}

# Function to open service in browser
open_service() {
    print_status "Opening service in browser..."
    minikube service aim-engine-service -n ${NAMESPACE}
}

# Main deployment function
deploy() {
    print_status "Starting AIM Engine Minikube deployment..."
    
    # Pre-flight checks
    check_kubectl
    check_minikube
    setup_minikube
    
    # Create namespace
    create_namespace
    
    # Deploy resources
    deploy_minikube_resources
    
    # Wait for deployment
    wait_for_deployment
    
    # Show status
    show_status
    
    # Show service URLs
    get_service_url
    
    print_success "AIM Engine Minikube deployment completed successfully!"
    print_status "You can access the service using: minikube service aim-engine-service -n ${NAMESPACE}"
}

# Function to show usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy      # Deploy AIM Engine to Minikube"
    echo "  status      # Show deployment status"
    echo "  logs        # Show recent logs"
    echo "  open        # Open service in browser"
    echo "  cleanup     # Clean up deployment"
    echo "  help        # Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy   # Deploy the application"
    echo "  $0 status   # Check deployment status"
    echo "  $0 logs     # View application logs"
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
    "open")
        open_service
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