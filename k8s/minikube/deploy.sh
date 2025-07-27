#!/bin/bash

# Minikube Deployment Script for AIM Engine
# Usage: ./deploy.sh

set -e

echo "🚀 Starting AIM Engine Minikube deployment..."

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v minikube &> /dev/null; then
        echo "❌ minikube not found. Please install minikube."
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

# Check Minikube status
check_minikube() {
    echo "🔍 Checking Minikube status..."
    
    if ! minikube status &> /dev/null; then
        echo "⚠️  Minikube not running. Starting Minikube..."
        minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=20g
    else
        echo "✅ Minikube is running"
    fi
}

# Enable Minikube addons
enable_addons() {
    echo "🔧 Enabling Minikube addons..."
    
    minikube addons enable ingress
    minikube addons enable storage-provisioner
    
    echo "✅ Minikube addons enabled"
}

# Build Docker image
build_image() {
    echo "🔨 Building Docker image..."
    
    # Check if TGI mode is requested
    if [ "$1" = "tgi" ]; then
        echo "🔧 Building TGI-enabled image..."
        docker build -f ../Dockerfile.aim-tgi -t aim-tgi:latest ..
        minikube image load aim-tgi:latest
        echo "✅ TGI Docker image built and loaded"
    else
        echo "🔧 Building vLLM image..."
        docker build -f ../Dockerfile.aim-vllm -t aim-vllm:latest ..
        minikube image load aim-vllm:latest
        echo "✅ vLLM Docker image built and loaded"
    fi
}

# Deploy to Minikube
deploy() {
    echo "🚀 Deploying to Minikube with recipe support..."
    
    # Check if TGI mode is requested
    DEPLOYMENT_FILE="deployment-with-recipes.yaml"
    if [ "$1" = "tgi" ]; then
        echo "🔧 Using TGI deployment..."
        DEPLOYMENT_FILE="deployment-with-tgi.yaml"
    else
        echo "🔧 Using vLLM deployment..."
    fi
    
    # Apply common resources
    kubectl apply -f ../common/namespace.yaml
    kubectl apply -f ../common/configmap.yaml
    
    # Apply Minikube-specific resources
    kubectl apply -f storage.yaml
    kubectl apply -f rbac.yaml
    
    # Apply recipe-related resources
    kubectl apply -f recipes-configmap.yaml
    kubectl apply -f recipe-selector-job.yaml
    
    # Wait for recipe selection to complete
    echo "⏳ Waiting for recipe selection to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/aim-engine-recipe-selector-hook -n aim-engine
    
    # Apply deployment with recipe support
    kubectl apply -f $DEPLOYMENT_FILE
    kubectl apply -f service.yaml
    
    # Apply monitoring (optional - requires Prometheus Operator)
    if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        echo "📊 Applying monitoring components..."
        kubectl apply -f monitoring.yaml
    else
        echo "⚠️  Prometheus Operator not detected, skipping monitoring setup"
        echo "   To enable monitoring, install Prometheus Operator first"
    fi
    
    echo "✅ Deployment completed with recipe support"
}

# Wait for deployment
wait_for_deployment() {
    echo "⏳ Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/aim-engine -n aim-engine
    
    echo "✅ Deployment is ready"
}

# Show status
show_status() {
    echo "📊 Deployment Status:"
    kubectl get all -n aim-engine
    
    echo ""
    echo "🎯 Recipe Information:"
    if kubectl get configmap aim-engine-recipe-config -n aim-engine &> /dev/null; then
        echo "Selected Recipe:"
        kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml | grep -A 10 "data:"
    else
        echo "No recipe configuration found"
    fi
    
    echo ""
    echo "🌐 Service Access:"
    echo "Internal: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine"
    echo "External: minikube service aim-engine-service -n aim-engine"
    echo "Recipe Info: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine && curl http://localhost:8000/recipe"
    echo "Metrics: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine && curl http://localhost:8000/metrics"
    
    echo ""
    echo "📝 Recent Logs:"
    kubectl logs -n aim-engine deployment/aim-engine --tail=10
    
    echo ""
    echo "📊 Monitoring Status:"
    if kubectl get namespace aim-engine-monitoring &> /dev/null; then
        echo "Monitoring namespace exists"
        if kubectl get servicemonitor -n aim-engine-monitoring &> /dev/null; then
            echo "ServiceMonitor configured"
        else
            echo "ServiceMonitor not found (Prometheus Operator may not be installed)"
        fi
    else
        echo "Monitoring not enabled"
    fi
}

# Main execution
main() {
    check_prerequisites
    check_minikube
    enable_addons
    build_image "$1"
    deploy "$1"
    wait_for_deployment
    show_status
    
    echo ""
    echo "🎉 Minikube deployment completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test the service: minikube service aim-engine-service -n aim-engine"
    echo "2. View logs: kubectl logs -f deployment/aim-engine -n aim-engine"
    echo "3. Access shell: kubectl exec -it deployment/aim-engine -n aim-engine -- bash"
}

# Run main function
main "$@" 