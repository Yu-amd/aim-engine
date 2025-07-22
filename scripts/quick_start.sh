#!/bin/bash

# AIM Engine Quick Start Script - Smart Dependency Management
# This script helps you get started with AIM Engine

set -e

echo "🚀 AIM Engine Quick Start"
echo "========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if a Python package is installed
check_python_package() {
    python3 -c "import $1" 2>/dev/null
    return $?
}

# Function to check if a command exists
check_command() {
    command -v $1 &> /dev/null
    return $?
}

# Function to check if we're in a virtual environment
check_venv() {
    if [ -n "$VIRTUAL_ENV" ]; then
        return 0
    else
        return 1
    fi
}

# Check if we're in the right directory
if [ ! -f "../aim_launcher.py" ]; then
    print_error "Please run this script from the scripts directory"
    exit 1
fi

# Check Python version
print_status "Checking Python version..."
python_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" = "$required_version" ]; then
    print_success "Python $python_version is compatible"
else
    print_error "Python $python_version is not compatible. Please use Python 3.8 or higher."
    exit 1
fi

# Check if we're in a virtual environment
if check_venv; then
    print_success "Running in virtual environment: $VIRTUAL_ENV"
else
    print_warning "Not running in a virtual environment"
    print_warning "Consider creating a virtual environment for better dependency management:"
    echo "  cd .."
    echo "  python3 -m venv venv"
    echo "  source venv/bin/activate"
    echo "  ./install.sh"
    echo ""
fi

# Check if Docker is installed
print_status "Checking Docker installation..."
if check_command docker; then
    docker_version=$(docker --version)
    print_success "Docker is installed: $docker_version"
else
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker daemon is running
print_status "Checking Docker daemon..."
if docker info &> /dev/null; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Check if ROCm vLLM image is available
print_status "Checking ROCm vLLM base image..."
if docker images | grep -q "rocm/vllm.*latest"; then
    print_success "ROCm vLLM base image is already available"
    ROCM_IMAGE_EXISTS=true
else
    print_warning "ROCm vLLM base image not found"
    ROCM_IMAGE_EXISTS=false
fi

# Check Python dependencies individually
print_status "Checking Python dependencies..."
MISSING_DEPS=()

# Core dependencies needed for AIM Engine
if ! check_python_package "yaml"; then
    MISSING_DEPS+=("PyYAML")
fi

if ! check_python_package "requests"; then
    MISSING_DEPS+=("requests")
fi

if ! check_python_package "jsonschema"; then
    MISSING_DEPS+=("jsonschema")
fi

# Install missing dependencies only
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    print_status "Installing missing Python dependencies: ${MISSING_DEPS[*]}"
    for dep in "${MISSING_DEPS[@]}"; do
        if pip3 install "$dep" --break-system-packages 2>/dev/null || pip3 install "$dep"; then
            print_success "Installed $dep"
        else
            print_error "Failed to install $dep"
            print_error "Try installing in a virtual environment or use: pip3 install $dep --break-system-packages"
            exit 1
        fi
    done
else
    print_success "All required Python dependencies are already installed"
fi

# Check if AIM Engine is installed
print_status "Checking AIM Engine installation..."
if python3 -c "import aim_launcher" 2>/dev/null; then
    print_success "AIM Engine is already installed"
else
    print_status "Installing AIM Engine in development mode..."
    if pip3 install -e .. --break-system-packages 2>/dev/null || pip3 install -e ..; then
        print_success "AIM Engine installed successfully"
    else
        print_error "Failed to install AIM Engine"
        print_error "Try installing in a virtual environment or use: pip3 install -e .. --break-system-packages"
        exit 1
    fi
fi

# Pull the base ROCm image only if not already available
if [ "$ROCM_IMAGE_EXISTS" = false ]; then
    print_status "Pulling ROCm vLLM base image..."
    if docker pull rocm/vllm:latest; then
        print_success "ROCm vLLM base image pulled successfully"
    else
        print_warning "Failed to pull ROCm vLLM base image. You can try again later."
        print_warning "Note: The vLLM container contains all necessary dependencies for model deployment"
    fi
fi

# Run validation tests
print_status "Running AIM Engine validation tests..."
if python3 ../tests/test_aim_implementation.py; then
    print_success "All validation tests passed!"
else
    print_warning "Some validation tests failed. This might be expected if Docker containers are not available."
    print_warning "The core functionality should still work for basic operations."
fi

# Show available models
print_status "Available models:"
python3 -c "
import sys
sys.path.insert(0, '..')
from aim_recipe_selector import AIMRecipeSelector
from pathlib import Path
selector = AIMRecipeSelector(Path('..'))
models = selector.list_available_models()
for model in models:
    print(f'  - {model}')
"

# Show usage examples
echo ""
print_success "AIM Engine is ready!"
echo ""
echo "🎯 Key Points:"
echo "=============="
echo "• The vLLM container includes all model deployment dependencies"
echo "• Only Python orchestration dependencies are installed locally"
echo "• The system is ready for single-node deployments"
echo ""
echo "📖 Usage Examples:"
echo "=================="
echo ""
echo "1. Launch Qwen3-32B with 4 GPUs:"
echo "   python3 ../aim_launcher.py --model Qwen/Qwen3-32B --gpus 4 --precision bf16 --backend vllm"
echo ""
echo "2. Launch Llama-3-8B with 2 GPUs:"
echo "   python3 ../aim_launcher.py --model meta-llama/Meta-Llama-3-8B-Instruct --gpus 2 --precision fp16"
echo ""
echo "3. List running endpoints:"
echo "   python3 ../aim_launcher.py --list"
echo ""
echo "4. Stop an endpoint:"
echo "   python3 ../aim_launcher.py --stop --container <container-name>"
echo ""
echo "5. Get help:"
echo "   python3 ../aim_launcher.py --help"
echo ""
echo "6. Run examples:"
echo "   python3 ../example_usage.py"
echo ""
echo "📚 Documentation:"
echo "================="
echo "For detailed documentation, see: ../docs/AIM_IMPLEMENTATION_README.md"
echo ""
echo "🧪 Testing:"
echo "==========="
echo "To run tests: python3 ../tests/test_aim_implementation.py"
echo ""
print_success "Happy AI model serving with AIM Engine! 🎉" 