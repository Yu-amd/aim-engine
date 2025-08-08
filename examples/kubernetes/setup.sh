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
    
    # Deploy the example
    print_status "Deploying Basic AIM..."
    kubectl apply -f "$SCRIPT_DIR/basic-aim/"
    
    # Wait for deployment
    print_status "Waiting for AIM to be ready..."
    kubectl wait --for=condition=available deployment/basic-aim -n aim-engine --timeout=300s
    
    # Check status
    print_status "Checking AIM status..."
    kubectl get aimendpoint -n aim-engine
    
    # Run the client
    print_status "Running Basic AIM client..."
    python3 "$SCRIPT_DIR/basic-aim/client.py"
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
    echo "3. Run Basic AIM Example"
    echo "4. Run Multi-Model Example"
    echo "5. Run Cached AIM Example"
    echo "6. Run Scalable AIM Example"
    echo "7. Cleanup All Examples"
    echo "8. Exit"
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
                run_multi_model
                ;;
            5)
                run_cached_aim
                ;;
            6)
                run_scalable_aim
                ;;
            7)
                cleanup_examples
                ;;
            8)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-8."
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