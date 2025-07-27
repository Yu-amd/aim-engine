#!/bin/bash

# AIM Engine Recipe-Aware Deployment Script
# This script demonstrates all 5 implemented features:
# 1. Recipe-aware Helm charts with dynamic configuration
# 2. Recipe selection hooks for automatic optimization
# 3. Recipe validation in Kubernetes admission controllers
# 4. Recipe-based monitoring and alerting
# 5. Recipe performance dashboards

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="aim-engine"
MONITORING_NAMESPACE="aim-engine-monitoring"
HELM_CHART_PATH="./helm"
REGISTRY=${1:-"localhost:5000"}
IMAGE_TAG=${2:-"latest"}

echo -e "${BLUE}🚀 AIM Engine Recipe-Aware Deployment${NC}"
echo "=================================="
echo "Registry: $REGISTRY"
echo "Image Tag: $IMAGE_TAG"
echo "Namespace: $NAMESPACE"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Function to create namespaces
create_namespaces() {
    print_status "Creating namespaces..."
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Namespaces created"
}

# Function to deploy admission controller
deploy_admission_controller() {
    print_status "Deploying recipe validation admission controller..."
    
    # Apply admission controller manifests
    kubectl apply -f admission-controller/recipe-validator.yaml
    
    # Wait for admission controller to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/aim-engine-recipe-validator -n $NAMESPACE
    
    print_status "Admission controller deployed"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_status "Deploying recipe-based monitoring..."
    
    # Apply monitoring manifests
    kubectl apply -f monitoring/recipe-monitoring.yaml
    kubectl apply -f monitoring/recipe-dashboard.yaml
    
    print_status "Monitoring deployed"
}

# Function to deploy with auto-selection
deploy_with_auto_selection() {
    print_status "Deploying with automatic recipe selection..."
    
    helm upgrade --install aim-engine $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --set image.repository=$REGISTRY/aim-vllm \
        --set image.tag=$IMAGE_TAG \
        --set aim_engine.recipe.auto_select=true \
        --set aim_engine.recipe.model_id="Qwen/Qwen3-32B" \
        --set aim_engine.recipe.fallback_enabled=true \
        --wait --timeout=600s
    
    print_status "Deployment with auto-selection completed"
}

# Function to deploy with configuration overrides
deploy_with_overrides() {
    print_status "Deploying with configuration overrides..."
    
    helm upgrade --install aim-engine-override $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --set image.repository=$REGISTRY/aim-vllm \
        --set image.tag=$IMAGE_TAG \
        --set aim_engine.recipe.auto_select=true \
        --set aim_engine.recipe.model_id="Qwen/Qwen3-32B" \
        --set aim_engine.recipe.overrides.enabled=true \
        --set aim_engine.recipe.overrides.gpu_count=4 \
        --set aim_engine.recipe.overrides.precision="bf16" \
        --set aim_engine.recipe.overrides.vllm_args.max_model_len=32768 \
        --set aim_engine.recipe.overrides.vllm_args.gpu_memory_utilization=0.9 \
        --wait --timeout=600s
    
    print_status "Deployment with overrides completed"
}

# Function to deploy with specific recipe
deploy_with_specific_recipe() {
    print_status "Deploying with specific recipe..."
    
    helm upgrade --install aim-engine-specific $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --set image.repository=$REGISTRY/aim-vllm \
        --set image.tag=$IMAGE_TAG \
        --set aim_engine.recipe.auto_select=false \
        --set aim_engine.recipe.model_id="Qwen/Qwen3-32B" \
        --set aim_engine.resources.gpu_count=2 \
        --set aim_engine.hardware.precision="bf16" \
        --wait --timeout=600s
    
    print_status "Deployment with specific recipe completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check pods
    kubectl get pods -n $NAMESPACE
    
    # Check services
    kubectl get services -n $NAMESPACE
    
    # Check recipe selector job
    kubectl get jobs -n $NAMESPACE
    
    # Check admission controller
    kubectl get validatingwebhookconfigurations | grep aim-engine
    
    # Check monitoring
    kubectl get servicemonitors -n $MONITORING_NAMESPACE
    kubectl get prometheusrules -n $MONITORING_NAMESPACE
    
    print_status "Deployment verification completed"
}

# Function to show recipe information
show_recipe_info() {
    print_status "Recipe Information:"
    
    # Get recipe selector job logs
    echo ""
    echo "Recipe Selection Logs:"
    kubectl logs -n $NAMESPACE job/aim-engine-recipe-selector-hook --tail=20
    
    # Show available recipes
    echo ""
    echo "Available Recipes:"
    kubectl get configmap -n $NAMESPACE aim-engine-recipes -o yaml | grep "recipe_id:"
    
    # Show current configuration
    echo ""
    echo "Current Configuration:"
    kubectl get configmap -n $NAMESPACE aim-engine-recipes -o yaml
}

# Function to show monitoring access
show_monitoring_access() {
    print_status "Monitoring Access Information:"
    
    echo ""
    echo "Grafana Dashboard:"
    echo "  URL: http://localhost:3000 (if port-forwarded)"
    echo "  Dashboard: AIM Engine Recipe Performance Dashboard"
    
    echo ""
    echo "Prometheus Metrics:"
    echo "  URL: http://localhost:9090 (if port-forwarded)"
    echo "  Query: aim_recipe_selection_total"
    
    echo ""
    echo "Alerts:"
    kubectl get prometheusrules -n $MONITORING_NAMESPACE aim-engine-recipe-alerts -o yaml
}

# Function to cleanup
cleanup() {
    print_warning "Cleaning up deployment..."
    
    # Delete Helm releases
    helm uninstall aim-engine -n $NAMESPACE --wait
    helm uninstall aim-engine-override -n $NAMESPACE --wait
    helm uninstall aim-engine-specific -n $NAMESPACE --wait
    
    # Delete admission controller
    kubectl delete -f admission-controller/recipe-validator.yaml --ignore-not-found=true
    
    # Delete monitoring
    kubectl delete -f monitoring/recipe-monitoring.yaml --ignore-not-found=true
    kubectl delete -f monitoring/recipe-dashboard.yaml --ignore-not-found=true
    
    # Delete namespaces
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true
    
    print_status "Cleanup completed"
}

# Main deployment function
main() {
    case "${1:-auto}" in
        "auto")
            check_prerequisites
            create_namespaces
            deploy_admission_controller
            deploy_monitoring
            deploy_with_auto_selection
            verify_deployment
            show_recipe_info
            show_monitoring_access
            ;;
        "override")
            check_prerequisites
            create_namespaces
            deploy_admission_controller
            deploy_monitoring
            deploy_with_overrides
            verify_deployment
            show_recipe_info
            show_monitoring_access
            ;;
        "specific")
            check_prerequisites
            create_namespaces
            deploy_admission_controller
            deploy_monitoring
            deploy_with_specific_recipe
            verify_deployment
            show_recipe_info
            show_monitoring_access
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Usage: $0 [auto|override|specific|cleanup] [registry] [image-tag]"
            echo ""
            echo "Deployment modes:"
            echo "  auto     - Deploy with automatic recipe selection"
            echo "  override - Deploy with configuration overrides"
            echo "  specific - Deploy with specific recipe configuration"
            echo "  cleanup  - Clean up all deployments"
            echo ""
            echo "Examples:"
            echo "  $0 auto localhost:5000 latest"
            echo "  $0 override localhost:5000 v1.0.0"
            echo "  $0 specific localhost:5000 latest"
            echo "  $0 cleanup"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 