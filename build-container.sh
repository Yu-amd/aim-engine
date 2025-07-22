#!/bin/bash

# AIM Engine Container Build Script

set -e

echo "🚀 Building AIM Engine Container"
echo "================================"

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

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Docker is available and running"
}

# Build the container
build_container() {
    local tag=${1:-"aim-engine:latest"}
    
    print_status "Building AIM Engine container with tag: $tag"
    
    if docker build -t "$tag" .; then
        print_success "Container built successfully"
    else
        print_error "Failed to build container"
        exit 1
    fi
}

# Test the container
test_container() {
    local tag=${1:-"aim-engine:latest"}
    
    print_status "Testing AIM Engine container"
    
    # Test basic functionality
    if docker run --rm "$tag" aim-engine help >/dev/null 2>&1; then
        print_success "Basic functionality test passed"
    else
        print_error "Basic functionality test failed"
        return 1
    fi
    
    # Test Python imports
    if docker run --rm "$tag" python3 -c "import aim_launcher; print('OK')" >/dev/null 2>&1; then
        print_success "Python imports test passed"
    else
        print_error "Python imports test failed"
        return 1
    fi
    
    print_success "All container tests passed"
}

# Run the container interactively
run_interactive() {
    local tag=${1:-"aim-engine:latest"}
    
    print_status "Starting AIM Engine container in interactive mode"
    print_warning "Press Ctrl+C to exit"
    
    docker run -it --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /workspace/model-cache:/workspace/model-cache \
        -v "$(pwd)/models:/opt/aim-engine/models:ro" \
        -v "$(pwd)/recipes:/opt/aim-engine/recipes:ro" \
        -v "$(pwd)/templates:/opt/aim-engine/templates:ro" \
        -p 8000-8010:8000-8010 \
        --gpus all \
        "$tag"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  build [TAG]     Build the container (default: aim-engine:latest)"
    echo "  test [TAG]      Test the container"
    echo "  run [TAG]       Run the container interactively"
    echo "  all [TAG]       Build, test, and run the container"
    echo
    echo "Examples:"
    echo "  $0 build                    # Build with default tag"
    echo "  $0 build my-aim:latest      # Build with custom tag"
    echo "  $0 test                     # Test the container"
    echo "  $0 run                      # Run interactively"
    echo "  $0 all                      # Build, test, and run"
}

# Main execution
main() {
    check_docker
    
    case "${1:-build}" in
        "build")
            build_container "$2"
            ;;
        "test")
            test_container "$2"
            ;;
        "run")
            run_interactive "$2"
            ;;
        "all")
            build_container "$2"
            test_container "$2"
            run_interactive "$2"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 