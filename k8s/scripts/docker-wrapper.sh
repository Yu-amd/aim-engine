#!/bin/bash

# Docker wrapper script to handle permission issues
# This script ensures Docker commands work regardless of user group membership

# Function to check if Docker is accessible
check_docker_access() {
    if docker ps > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get Docker access
get_docker_access() {
    # Try multiple methods to get Docker access
    
    # Method 1: Check if user is in docker group
    if groups | grep -q docker; then
        # User is in docker group, try newgrp
        if newgrp docker -c "docker ps > /dev/null 2>&1" 2>/dev/null; then
            newgrp docker -c "docker $*"
            return $?
        fi
    fi
    
    # Method 2: Try sudo
    if sudo docker ps > /dev/null 2>&1; then
        sudo docker "$@"
        return $?
    fi
    
    # Method 3: Try temporary socket permission change
    if sudo chmod 666 /var/run/docker.sock 2>/dev/null; then
        docker "$@"
        local result=$?
        # Restore permissions
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        return $result
    fi
    
    # Method 4: Last resort - try with elevated privileges
    echo "Warning: Using elevated privileges for Docker access" >&2
    sudo docker "$@"
    return $?
}

# Main execution
if check_docker_access; then
    # Docker is accessible, run normally
    docker "$@"
else
    # Docker is not accessible, use wrapper
    get_docker_access "$@"
fi 