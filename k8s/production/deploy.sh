#!/bin/bash

# Production Deployment Script for AIM Engine
# Usage: ./deploy.sh [registry-url]

set -e

REGISTRY=${1:-localhost:5000}
REGISTRY=${2:-localhost:5000}
IMAGE_TAG=${3:-latest}

echo "🚀 Starting AIM Engine Production deployment..."
echo "Registry: $REGISTRY"
echo "Image Tag: $IMAGE_TAG"

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ docker not found. Please install docker."
        exit 1
    fi
    
    # Check if we're connected to a cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Not connected to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

# Install AMD GPU device plugin
install_gpu_plugin() {
    echo "🔧 Installing AMD GPU device plugin..."
    
    kubectl create -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml
    echo "✅ AMD GPU device plugin installed"
}

# Verify AMD GPU detection
verify_gpu_detection() {
    echo "🔍 Verifying AMD GPU detection..."
    
    kubectl get nodes -l amd.com/gpu=true
    kubectl get nodes -o json | jq '.items[0].status.allocatable."amd.com/gpu"'
    
    echo "✅ AMD GPU detection verified"
}

# Build and push Docker image
build_and_push_image() {
    echo "🔨 Building and pushing Docker image..."
    
    # Build the image
    docker build -f ../../Dockerfile.aim-vllm -t $REGISTRY/aim-vllm:$IMAGE_TAG ../..
    
    # Push to registry
    docker push $REGISTRY/aim-vllm:$IMAGE_TAG
    
    echo "✅ Docker image built and pushed"
}

# Update deployment for AMD GPUs
update_deployment() {
    echo "🔧 Updating deployment for AMD GPUs..."
    
    # Create a temporary deployment file
    cp deployment.yaml deployment-amd.yaml
    
    # Update image tag
    sed -i "s|aim-vllm:latest|$REGISTRY/aim-vllm:$IMAGE_TAG|g" deployment-amd.yaml
    
    echo "✅ Deployment updated for AMD GPUs"
}

# Deploy to production
deploy() {
    echo "🚀 Deploying to production..."
    
    # Apply common resources
    kubectl apply -f ../common/namespace.yaml
    kubectl apply -f ../common/configmap.yaml
    
    # Apply production resources
    kubectl apply -f storage.yaml
    kubectl apply -f rbac.yaml
    kubectl apply -f deployment-amd.yaml
    kubectl apply -f service.yaml
    kubectl apply -f ingress.yaml
    kubectl apply -f hpa.yaml
    kubectl apply -f monitoring.yaml
    
    echo "✅ Production deployment completed"
}

# Wait for deployment
wait_for_deployment() {
    echo "⏳ Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=600s deployment/aim-engine -n aim-engine
    
    echo "✅ Deployment is ready"
}

# Show status
show_status() {
    echo "📊 Deployment Status:"
    kubectl get all -n aim-engine
    
    echo ""
    echo "🔍 GPU Allocation:"
    kubectl describe pod -n aim-engine -l app=aim-engine | grep -A 5 "Allocated resources"
    
    echo ""
    echo "🌐 Service Access:"
    kubectl get svc -n aim-engine
    
    echo ""
    echo "📝 Recent Logs:"
    kubectl logs -n aim-engine deployment/aim-engine --tail=10
}

# Test AMD GPU access
test_gpu_access() {
    echo "🧪 Testing AMD GPU access..."
    
    kubectl exec -it deployment/aim-engine -n aim-engine -- rocm-smi
    
    echo "✅ AMD GPU access test completed"
}

# Cleanup
cleanup() {
    echo "🧹 Cleaning up temporary files..."
    rm -f deployment-amd.yaml
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    check_prerequisites
    install_gpu_plugin
    verify_gpu_detection
    build_and_push_image
    update_deployment
    deploy
    wait_for_deployment
    show_status
    test_gpu_access
    cleanup
    
    echo ""
    echo "🎉 Production deployment completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test the API endpoints"
    echo "2. Monitor GPU usage"
    echo "3. Configure monitoring and alerting"
    echo "4. Set up SSL/TLS certificates"
}

# Run main function
main "$@" 