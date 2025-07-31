#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPERATOR_NAMESPACE="aim-engine-operator"
OPERATOR_IMAGE="localhost:5000/aim-engine-operator:latest"
REGISTRY_URL="localhost:5000"

echo -e "${BLUE}AIM Engine Kubernetes Operator Installation${NC}"
echo "=============================================="

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is not installed${NC}"
    exit 1
fi

# Check if we can connect to Kubernetes
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace $OPERATOR_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Build and push operator image
echo -e "${YELLOW}Building operator image...${NC}"
cd "$(dirname "$0")/.."
docker build -t $OPERATOR_IMAGE -f Dockerfile .

echo -e "${YELLOW}Pushing operator image to registry...${NC}"
docker push $OPERATOR_IMAGE

# Install CRDs
echo -e "${YELLOW}Installing Custom Resource Definitions...${NC}"
kubectl apply -f config/crd/bases/

# Install RBAC
echo -e "${YELLOW}Installing RBAC resources...${NC}"
kubectl apply -f config/rbac/

# Install operator deployment
echo -e "${YELLOW}Installing operator deployment...${NC}"
kubectl apply -f config/manager/

# Wait for operator to be ready
echo -e "${YELLOW}Waiting for operator to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/aim-engine-operator-controller-manager -n $OPERATOR_NAMESPACE

# Create aim-engine namespace for examples
echo -e "${YELLOW}Creating aim-engine namespace for examples...${NC}"
kubectl create namespace aim-engine --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ AIM Engine Operator installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Create a recipe: kubectl apply -f examples/aimrecipe-example.yaml"
echo "2. Create a cache: kubectl apply -f examples/aimcache-example.yaml"
echo "3. Deploy an endpoint: kubectl apply -f examples/aimendpoint-example.yaml"
echo ""
echo -e "${BLUE}Check operator status:${NC}"
echo "kubectl get pods -n $OPERATOR_NAMESPACE"
echo "kubectl logs -f deployment/aim-engine-operator-controller-manager -n $OPERATOR_NAMESPACE" 