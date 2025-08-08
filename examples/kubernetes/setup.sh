#!/bin/bash

# AIM Engine Kubernetes Examples Setup Script
# This script sets up the Python environment and provides a menu for running examples

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/kubernetes-venv"
VENV_ACTIVATE="$VENV_DIR/bin/activate"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if virtual environment is active
is_venv_active() {
    [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]
}

# Function to setup Python virtual environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    # Check if python3 is available
    if ! command_exists python3; then
        print_error "python3 is not installed. Please install Python 3 first."
        exit 1
    fi
    
    # Install python3-venv if not available
    if ! python3 -c "import venv" 2>/dev/null; then
        print_status "Installing python3-venv..."
        sudo apt update
        sudo apt install -y python3-venv
    fi
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "$VENV_DIR" ]]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        print_success "Virtual environment created at $VENV_DIR"
    else
        print_status "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source "$VENV_ACTIVATE"
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Install dependencies
    print_status "Installing Python dependencies..."
    pip install kubernetes requests flask
    
    print_success "Python environment setup complete!"
}

# Function to check AIM Engine operator status
check_operator_status() {
    print_status "Checking AIM Engine operator status..."
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install Kubernetes CLI first."
        return 1
    fi
    
    # Check if operator is running
    if kubectl get pods -n aim-engine-system 2>/dev/null | grep -q "aim-engine-operator-controller-manager.*Running"; then
        print_success "AIM Engine operator is running"
        return 0
    else
        print_warning "AIM Engine operator is not running or not found"
        print_status "You may need to deploy the operator first:"
        echo "  cd k8s/operator && ./scripts/setup-and-test-operator.sh"
        return 1
    fi
}

# Function to check CRDs
check_crds() {
    print_status "Checking Custom Resource Definitions..."
    
    local crds_found=0
    
    if kubectl get crd aimendpoints.aim.engine.amd.com >/dev/null 2>&1; then
        print_success "AIMEndpoint CRD found"
        ((crds_found++))
    else
        print_warning "AIMEndpoint CRD not found"
    fi
    
    if kubectl get crd aimrecipes.aim.engine.amd.com >/dev/null 2>&1; then
        print_success "AIMRecipe CRD found"
        ((crds_found++))
    else
        print_warning "AIMRecipe CRD not found"
    fi
    
    if kubectl get crd aimcaches.aim.engine.amd.com >/dev/null 2>&1; then
        print_success "AIMCache CRD found"
        ((crds_found++))
    else
        print_warning "AIMCache CRD not found"
    fi
    
    if [[ $crds_found -eq 3 ]]; then
        print_success "All CRDs are available"
    elif [[ $crds_found -gt 0 ]]; then
        print_warning "Some CRDs are available ($crds_found/3). This may be sufficient for basic examples."
    else
        print_error "No CRDs found. The operator may not be deployed."
        print_status "You may need to deploy the operator first:"
        echo "  cd k8s/operator && ./scripts/setup-and-test-operator.sh"
    fi
    
    return 0
}

# Function to run basic AIM example
run_basic_aim() {
    print_status "Running Basic AIM example..."
    
    # Ensure virtual environment is active
    if ! is_venv_active; then
        source "$VENV_ACTIVATE"
    fi
    
    # Check available GPU resources first
    print_status "Checking available GPU resources..."
    local available_gpus=$(kubectl get nodes -o json | jq -r '.items[0].status.allocatable."amd.com/gpu"' 2>/dev/null || echo "0")
    local used_gpus=$(kubectl get pods -n aim-engine -o json | jq -r '.items[] | select(.status.phase == "Running") | .spec.containers[0].resources.requests."amd.com/gpu" // 0' 2>/dev/null | awk '{sum += $1} END {print sum}')
    
    print_status "Available GPUs: $available_gpus, Currently used: $used_gpus"
    
    if [[ "$available_gpus" -le "$used_gpus" ]]; then
        print_warning "No GPU resources available. The basic-aim example requires 1 GPU."
        print_status "Options:"
        echo "  1. Stop the existing aim-engine deployment: kubectl scale deployment aim-engine --replicas=0 -n aim-engine"
        echo "  2. Use a different example that doesn't require GPU"
        echo "  3. Wait for GPU resources to become available"
        read -p "Would you like to stop the aim-engine deployment to free up GPU? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            print_status "Stopping aim-engine deployment..."
            kubectl scale deployment aim-engine --replicas=0 -n aim-engine
            print_status "Waiting for aim-engine pod to stop..."
            kubectl wait --for=delete pod -l app.kubernetes.io/name=aim-endpoint -n aim-engine --timeout=60s 2>/dev/null || true
            print_status "GPU should now be available. Continuing with basic-aim deployment..."
        else
            print_status "Skipping basic-aim deployment due to insufficient GPU resources."
            return 1
        fi
    fi
    
    # Deploy the example
    print_status "Deploying Basic AIM..."
    kubectl apply -f "$SCRIPT_DIR/basic-aim/"
    
    # Wait for deployment with better error handling
    print_status "Waiting for AIM to be ready..."
    if kubectl wait --for=condition=available deployment/basic-aim -n aim-engine --timeout=300s 2>/dev/null; then
        print_success "Basic AIM deployment is ready!"
    else
        print_warning "Basic AIM deployment is not ready yet. Checking pod status..."
        kubectl get pods -n aim-engine | grep basic-aim
        print_status "You can check pod details with: kubectl describe pod -n aim-engine -l app.kubernetes.io/instance=basic-aim"
        print_status "The pod might be waiting for GPU resources or downloading the model."
    fi
    
    # Check status
    print_status "Checking AIM status..."
    kubectl get aimendpoint -n aim-engine
    
    # Check if we should set up port forwarding
    print_status "Setting up port forwarding for basic-aim..."
    print_status "Port forwarding will be available at http://localhost:8000"
    print_status "Press Ctrl+C to stop port forwarding when done testing"
    
    # Start port forwarding in background
    kubectl port-forward svc/basic-aim 8000:8000 -n aim-engine &
    local port_forward_pid=$!
    
    # Wait a moment for port forwarding to start
    sleep 3
    
    # Run the client
    print_status "Running Basic AIM client..."
    if python3 "$SCRIPT_DIR/basic-aim/client.py"; then
        print_success "Basic AIM client completed successfully!"
    else
        print_warning "Basic AIM client encountered issues. The AIM might still be starting up."
        print_status "You can check the AIM logs with: kubectl logs -n aim-engine -l app.kubernetes.io/instance=basic-aim"
    fi
    
    # Stop port forwarding
    print_status "Stopping port forwarding..."
    kill $port_forward_pid 2>/dev/null || true
}

# Function to run basic AIM example (CPU-only)
run_basic_aim_cpu() {
    print_status "Running Basic AIM example (CPU-only)..."
    
    # Ensure virtual environment is active
    if ! is_venv_active; then
        source "$VENV_ACTIVATE"
    fi
    
    # Deploy the CPU-only example
    print_status "Deploying Basic AIM (CPU-only)..."
    kubectl apply -f "$SCRIPT_DIR/basic-aim/aimendpoint-cpu.yaml"
    
    # Wait for deployment with better error handling
    print_status "Waiting for AIM to be ready..."
    if kubectl wait --for=condition=available deployment/basic-aim-cpu -n aim-engine --timeout=300s 2>/dev/null; then
        print_success "Basic AIM (CPU-only) deployment is ready!"
    else
        print_warning "Basic AIM (CPU-only) deployment is not ready yet. Checking pod status..."
        kubectl get pods -n aim-engine | grep basic-aim-cpu
        print_status "You can check pod details with: kubectl describe pod -n aim-engine -l app.kubernetes.io/instance=basic-aim-cpu"
        print_status "The pod might be downloading the model (this can take several minutes)."
    fi
    
    # Check status
    print_status "Checking AIM status..."
    kubectl get aimendpoint -n aim-engine
    
    # Check if we should set up port forwarding
    print_status "Setting up port forwarding for basic-aim-cpu..."
    print_status "Port forwarding will be available at http://localhost:8001"
    print_status "Press Ctrl+C to stop port forwarding when done testing"
    
    # Start port forwarding in background
    kubectl port-forward svc/basic-aim-cpu 8001:8000 -n aim-engine &
    local port_forward_pid=$!
    
    # Wait a moment for port forwarding to start
    sleep 3
    
    # Run the client (modify to use port 8001)
    print_status "Running Basic AIM client (CPU-only)..."
    print_status "Note: CPU-only inference will be slower than GPU inference"
    
    # Create a temporary client script for CPU version
    local temp_client="$SCRIPT_DIR/basic-aim/client_cpu.py"
    cat > "$temp_client" << 'EOF'
#!/usr/bin/env python3
import requests
import time
import sys

def main():
    print("🚀 Basic AIM Client for Kubernetes (CPU-only)")
    print("=" * 50)
    
    base_url = "http://localhost:8001"
    
    # Check health
    print("Checking AIM health...")
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        if response.status_code == 200:
            print("✅ AIM is healthy!")
        else:
            print(f"❌ AIM health check failed: {response.status_code}")
            return
    except requests.exceptions.RequestException as e:
        print(f"❌ AIM is not healthy: {e}")
        print("The AIM might still be starting up. Please wait a few minutes and try again.")
        return
    
    # Test models endpoint
    print("\nTesting models endpoint...")
    try:
        response = requests.get(f"{base_url}/v1/models", timeout=10)
        if response.status_code == 200:
            models = response.json()
            print(f"✅ Models available: {models}")
        else:
            print(f"❌ Models endpoint failed: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Models endpoint error: {e}")
    
    print("\n✅ Basic AIM (CPU-only) test completed!")
    print("Note: CPU inference is slower than GPU inference")

if __name__ == "__main__":
    main()
EOF
    
    if python3 "$temp_client"; then
        print_success "Basic AIM (CPU-only) client completed successfully!"
    else
        print_warning "Basic AIM (CPU-only) client encountered issues. The AIM might still be starting up."
        print_status "You can check the AIM logs with: kubectl logs -n aim-engine -l app.kubernetes.io/instance=basic-aim-cpu"
    fi
    
    # Clean up temporary file
    rm -f "$temp_client"
    
    # Stop port forwarding
    print_status "Stopping port forwarding..."
    kill $port_forward_pid 2>/dev/null || true
}

# Function to run multi-model example
run_multi_model() {
    print_status "Running Multi-Model AIM example..."
    
    # Ensure virtual environment is active
    if ! is_venv_active; then
        source "$VENV_ACTIVATE"
    fi
    
    # Deploy the examples
    print_status "Deploying Multi-Model AIMs..."
    kubectl apply -f "$SCRIPT_DIR/multi-model/"
    
    # Wait for deployments
    print_status "Waiting for AIMs to be ready..."
    kubectl wait --for=condition=available deployment/qwen-7b-demo -n aim-engine --timeout=300s
    
    # Check status
    print_status "Checking AIM status..."
    kubectl get aimendpoint -n aim-engine
    
    # Run the client
    print_status "Running Multi-Model client..."
    python3 "$SCRIPT_DIR/multi-model/client.py"
}

# Function to run cached AIM example
run_cached_aim() {
    print_status "Running Cached AIM example..."
    
    # Ensure virtual environment is active
    if ! is_venv_active; then
        source "$VENV_ACTIVATE"
    fi
    
    # Deploy the example
    print_status "Deploying Cached AIM..."
    kubectl apply -f "$SCRIPT_DIR/cached-aim/"
    
    # Wait for deployment
    print_status "Waiting for AIM to be ready..."
    kubectl wait --for=condition=available deployment/cached-aim -n aim-engine --timeout=300s
    
    # Check status
    print_status "Checking AIM and cache status..."
    kubectl get aimendpoint -n aim-engine
    kubectl get pvc -n aim-engine
    
    # Run the client
    print_status "Running Cached AIM client..."
    python3 "$SCRIPT_DIR/cached-aim/client.py"
}

# Function to run scalable AIM example
run_scalable_aim() {
    print_status "Running Scalable AIM example..."
    
    # Ensure virtual environment is active
    if ! is_venv_active; then
        source "$VENV_ACTIVATE"
    fi
    
    # Deploy the example
    print_status "Deploying Scalable AIM..."
    kubectl apply -f "$SCRIPT_DIR/scalable-aim/"
    
    # Wait for deployment
    print_status "Waiting for AIM to be ready..."
    kubectl wait --for=condition=available deployment/scalable-aim -n aim-engine --timeout=300s
    
    # Check status
    print_status "Checking AIM and HPA status..."
    kubectl get aimendpoint -n aim-engine
    kubectl get hpa -n aim-engine
    
    # Run the load test
    print_status "Running load test..."
    python3 "$SCRIPT_DIR/scalable-aim/load_test.py"
}

# Function to cleanup examples
cleanup_examples() {
    print_status "Cleaning up all examples..."
    
    # Remove all AIMs
    kubectl delete aimendpoint --all -n aim-engine --ignore-not-found=true
    
    # Remove all recipes
    kubectl delete aimrecipe --all -n aim-engine --ignore-not-found=true
    
    # Remove all PVCs
    kubectl delete pvc --all -n aim-engine --ignore-not-found=true
    
    # Remove all deployments
    kubectl delete deployment --all -n aim-engine --ignore-not-found=true
    
    # Remove all services
    kubectl delete svc --all -n aim-engine --ignore-not-found=true
    
    # Remove all HPAs
    kubectl delete hpa --all -n aim-engine --ignore-not-found=true
    
    print_success "Cleanup complete!"
}

# Function to show status
show_status() {
    print_status "Current status:"
    echo
    
    # Check virtual environment
    if [[ -d "$VENV_DIR" ]]; then
        print_success "Virtual environment: $VENV_DIR"
    else
        print_warning "Virtual environment not found"
    fi
    
    if is_venv_active; then
        print_success "Virtual environment is active"
    else
        print_warning "Virtual environment is not active"
    fi
    
    echo
    
    # Check Kubernetes cluster
    if command_exists kubectl; then
        print_status "Kubernetes cluster:"
        kubectl get nodes
        echo
        
        # Check operator status
        check_operator_status
        echo
        
        # Check CRDs
        check_crds
        echo
        
        # Check AIMs
        print_status "AIM Endpoints:"
        kubectl get aimendpoint -n aim-engine 2>/dev/null || print_warning "No AIM endpoints found"
        echo
        
        # Check pods
        print_status "AIM Pods:"
        kubectl get pods -n aim-engine 2>/dev/null || print_warning "No AIM pods found"
    else
        print_warning "kubectl not found"
    fi
}

# Function to show menu
show_menu() {
    echo
    echo "=========================================="
    echo "    AIM Engine Kubernetes Examples"
    echo "=========================================="
    echo
    echo "1. Setup Python Environment"
    echo "2. Check Status"
    echo "3. Run Basic AIM Example (GPU)"
    echo "4. Run Basic AIM Example (CPU-only)"
    echo "5. Run Multi-Model Example"
    echo "6. Run Cached AIM Example"
    echo "7. Run Scalable AIM Example"
    echo "8. Cleanup All Examples"
    echo "9. Exit"
    echo
    echo "Note: Make sure the AIM Engine operator is deployed first!"
    echo "      Run: cd k8s/operator && ./scripts/setup-and-test-operator.sh"
    echo
}

# Function to handle menu selection
handle_menu() {
    while true; do
        show_menu
        read -p "Select an option (1-8): " choice
        
        case $choice in
            1)
                setup_python_env
                ;;
            2)
                show_status
                ;;
            3)
                run_basic_aim
                ;;
            4)
                run_basic_aim_cpu
                ;;
            5)
                run_multi_model
                ;;
            6)
                run_cached_aim
                ;;
            7)
                run_scalable_aim
                ;;
            8)
                cleanup_examples
                ;;
            9)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-9."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Main execution
main() {
    print_status "AIM Engine Kubernetes Examples Setup"
    print_status "Script directory: $SCRIPT_DIR"
    echo
    
    # Check if we're in the right directory
    if [[ ! -d "$SCRIPT_DIR/basic-aim" ]]; then
        print_error "This script must be run from the kubernetes examples directory"
        print_error "Expected: $SCRIPT_DIR/basic-aim"
        exit 1
    fi
    
    # Setup Python environment if virtual environment doesn't exist
    if [[ ! -d "$VENV_DIR" ]]; then
        print_status "Virtual environment not found. Setting up..."
        setup_python_env
    else
        print_status "Virtual environment found. Activating..."
        source "$VENV_ACTIVATE"
    fi
    
    # Show initial status
    show_status
    
    # Show menu
    handle_menu
}

# Run main function
main "$@" 