#!/bin/bash

# Quick fix for Kubernetes repository issues
set -e

echo "Fixing Kubernetes repository..."

# Remove old repository files
rm -f /etc/apt/sources.list.d/kubernetes.list
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes GPG key (correct URL)
curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository (correct URL)
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
apt update

# Install Kubernetes components
KUBERNETES_VERSION="1.28.0"
apt install -y kubelet=${KUBERNETES_VERSION}-00 kubeadm=${KUBERNETES_VERSION}-00 kubectl=${KUBERNETES_VERSION}-00

# Hold packages to prevent automatic updates
apt-mark hold kubelet kubeadm kubectl

echo "Kubernetes components installed successfully!"
echo "You can now continue with the cluster setup." 