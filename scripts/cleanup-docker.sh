#!/bin/bash

# AIM Engine Docker Cleanup Script
# This script stops and removes all AIM Engine Docker containers and resources

set -e

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

# Parse command line arguments
CLEANUP_ALL=false
CLEANUP_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEANUP_ALL=true
            shift
            ;;
        --images)
            CLEANUP_IMAGES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --all     Remove all containers and images"
            echo "  --images  Remove AIM Engine images"
            echo "  --help    Show this help message"
            echo ""
            echo "Default behavior: Stop and remove only AIM Engine containers"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Starting AIM Engine Docker cleanup..."

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log_error "docker is not installed"
    exit 1
fi

# Step 1: Stop and remove AIM Engine containers
log_info "Step 1: Stopping and removing AIM Engine containers..."

# Stop containers using aim-vllm image
AIM_CONTAINERS=$(docker ps -q --filter "ancestor=aim-vllm:latest" 2>/dev/null || true)
if [[ -n "$AIM_CONTAINERS" ]]; then
    log_info "Stopping AIM Engine containers..."
    docker stop $AIM_CONTAINERS || true
    
    log_info "Removing AIM Engine containers..."
    docker rm $AIM_CONTAINERS || true
else
    log_info "No running AIM Engine containers found"
fi

# Stop containers with aim-vllm in name
AIM_NAMED_CONTAINERS=$(docker ps -q --filter "name=aim-vllm" 2>/dev/null || true)
if [[ -n "$AIM_NAMED_CONTAINERS" ]]; then
    log_info "Stopping containers with 'aim-vllm' in name..."
    docker stop $AIM_NAMED_CONTAINERS || true
    docker rm $AIM_NAMED_CONTAINERS || true
fi

# Stop containers with aim-engine in name
AIM_ENGINE_CONTAINERS=$(docker ps -q --filter "name=aim-engine" 2>/dev/null || true)
if [[ -n "$AIM_ENGINE_CONTAINERS" ]]; then
    log_info "Stopping containers with 'aim-engine' in name..."
    docker stop $AIM_ENGINE_CONTAINERS || true
    docker rm $AIM_ENGINE_CONTAINERS || true
fi

log_success "AIM Engine containers cleaned up"

# Step 2: Remove AIM Engine images (if requested)
if [[ "$CLEANUP_IMAGES" == "true" || "$CLEANUP_ALL" == "true" ]]; then
    log_info "Step 2: Removing AIM Engine images..."
    
    # Remove aim-vllm images
    AIM_IMAGES=$(docker images -q aim-vllm 2>/dev/null || true)
    if [[ -n "$AIM_IMAGES" ]]; then
        log_info "Removing aim-vllm images..."
        docker rmi $AIM_IMAGES --force || true
    fi
    
    # Remove local registry images
    REGISTRY_IMAGES=$(docker images -q "localhost:5000/aim-vllm" 2>/dev/null || true)
    if [[ -n "$REGISTRY_IMAGES" ]]; then
        log_info "Removing local registry images..."
        docker rmi $REGISTRY_IMAGES --force || true
    fi
    
    log_success "AIM Engine images removed"
fi

# Step 3: Clean up all Docker resources (if requested)
if [[ "$CLEANUP_ALL" == "true" ]]; then
    log_warning "Step 3: Cleaning up all Docker resources..."
    
    # Stop all containers
    log_info "Stopping all containers..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Remove all containers
    log_info "Removing all containers..."
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove all images
    log_info "Removing all images..."
    docker rmi $(docker images -aq) --force 2>/dev/null || true
    
    # Clean up system
    log_info "Cleaning Docker system..."
    docker system prune -af || true
    
    # Clean up volumes
    log_info "Cleaning Docker volumes..."
    docker volume prune -f || true
    
    # Clean up networks
    log_info "Cleaning Docker networks..."
    docker network prune -f || true
    
    log_success "All Docker resources cleaned up"
fi

# Final success message
log_success "🎉 AIM Engine Docker cleanup completed!"
echo ""
log_info "Cleanup summary:"
if [[ "$CLEANUP_ALL" == "true" ]]; then
    echo "  ✅ All Docker containers and images removed"
elif [[ "$CLEANUP_IMAGES" == "true" ]]; then
    echo "  ✅ AIM Engine containers and images removed"
else
    echo "  ✅ AIM Engine containers stopped and removed"
fi
echo "" 