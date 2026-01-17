#!/bin/bash

# Script to install Strimzi Kafka Operator
# This script creates the Kafka namespace and installs the Strimzi operator

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_info "Starting Strimzi Kafka Operator installation..."
echo ""

# Step 1: Create Kafka namespace
print_step "1/4 - Creating Kafka namespace"
if kubectl get namespace kafka &> /dev/null; then
    print_warning "Namespace 'kafka' already exists. Skipping..."
else
    kubectl create namespace kafka
    print_info "Namespace 'kafka' created successfully"
fi
echo ""

# Step 2: Install Strimzi Operator
print_step "2/4 - Installing Strimzi Kafka Operator"
print_info "Downloading and applying Strimzi operator manifests from strimzi.io..."

if kubectl apply -f https://strimzi.io/install/latest?namespace=kafka -n kafka; then
    print_info "Strimzi operator installed successfully"
else
    print_error "Failed to install Strimzi operator"
    exit 1
fi
echo ""

# Step 3: Wait for operator to be ready
print_step "3/4 - Waiting for Strimzi operator to be ready (this may take a minute)..."
if kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s; then
    print_info "Strimzi operator is ready!"
else
    print_warning "Timeout waiting for operator. Check status with: kubectl get pods -n kafka"
fi
echo ""

# Step 4: Verify installation
print_step "4/4 - Verifying installation"
echo ""
print_info "Operator Deployment:"
kubectl get deployment -n kafka

echo ""
print_info "Operator Pods:"
kubectl get pods -n kafka

echo ""
print_info "Custom Resource Definitions (CRDs) installed:"
kubectl get crd | grep strimzi | head -5
echo "..."

echo ""
echo "========================================="
print_info "Strimzi Installation Complete!"
echo "========================================="
echo ""
print_info "Next Steps:"
echo ""
echo "1. Label your Kubernetes nodes for Kafka workloads:"
echo "   ./scripts/label-kafka-nodes.sh node-1 node-2 node-3"
echo ""
echo "2. (Optional) Apply node tuning for optimal performance:"
echo "   kubectl apply -f infra/terraform/kubernetes/node-tuning-daemonset.yaml"
echo ""
echo "3. Deploy the Kafka cluster:"
echo "   kubectl apply -f platform/kafka/cluster.yaml"
echo ""
echo "4. Monitor cluster deployment:"
echo "   kubectl get kafka -n kafka -w"
echo ""
echo "For detailed documentation, see: docs/GETTING_STARTED.md"
echo ""
