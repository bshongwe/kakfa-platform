#!/bin/bash

# Script to label Kubernetes nodes for Kafka workloads
# Usage: ./label-kafka-nodes.sh <node1> <node2> <node3> ...

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if any nodes were provided
if [ $# -eq 0 ]; then
    print_error "No nodes specified."
    echo ""
    echo "Usage: $0 <node1> <node2> <node3> ..."
    echo ""
    echo "Available nodes:"
    kubectl get nodes --no-headers -o custom-columns=":metadata.name"
    exit 1
fi

# Minimum recommended nodes for production
MIN_NODES=3
if [ $# -lt $MIN_NODES ]; then
    print_warning "You are labeling less than $MIN_NODES nodes."
    print_warning "For production, it's recommended to have at least $MIN_NODES Kafka nodes."
    read -p "Do you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

print_info "Starting to label nodes for Kafka workloads..."
echo ""

# Array to track success/failure
declare -a successful_nodes
declare -a failed_nodes

# Label each node
for node in "$@"; do
    print_info "Processing node: $node"
    
    # Check if node exists
    if ! kubectl get node "$node" &> /dev/null; then
        print_error "Node '$node' does not exist. Skipping..."
        failed_nodes+=("$node")
        continue
    fi
    
    # Check if node is Ready
    node_status=$(kubectl get node "$node" --no-headers -o custom-columns=":status.conditions[?(@.type=='Ready')].status")
    if [ "$node_status" != "True" ]; then
        print_warning "Node '$node' is not in Ready state. Current status: $node_status"
        read -p "Do you want to label this node anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            failed_nodes+=("$node")
            continue
        fi
    fi
    
    # Apply the Kafka node label
    if kubectl label node "$node" node-role.kubernetes.io/kafka=true --overwrite; then
        print_info "Successfully labeled node '$node'"
        successful_nodes+=("$node")
    else
        print_error "Failed to label node '$node'"
        failed_nodes+=("$node")
    fi
    echo ""
done

# Summary
echo ""
echo "========================================="
echo "           LABELING SUMMARY"
echo "========================================="
echo ""

if [ ${#successful_nodes[@]} -gt 0 ]; then
    print_info "Successfully labeled ${#successful_nodes[@]} node(s):"
    for node in "${successful_nodes[@]}"; do
        echo "  ✓ $node"
    done
    echo ""
fi

if [ ${#failed_nodes[@]} -gt 0 ]; then
    print_error "Failed to label ${#failed_nodes[@]} node(s):"
    for node in "${failed_nodes[@]}"; do
        echo "  ✗ $node"
    done
    echo ""
fi

# Verification
if [ ${#successful_nodes[@]} -gt 0 ]; then
    print_info "Verifying labeled nodes..."
    kubectl get nodes -l node-role.kubernetes.io/kafka=true -o wide
    echo ""
    
    print_info "Node details:"
    for node in "${successful_nodes[@]}"; do
        echo ""
        echo "Node: $node"
        kubectl describe node "$node" | grep -A 10 "Labels:"
    done
fi

# Optional: Apply taint
echo ""
read -p "Do you want to taint these nodes to prevent non-Kafka workloads? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for node in "${successful_nodes[@]}"; do
        if kubectl taint node "$node" workload=kafka:NoSchedule --overwrite; then
            print_info "Tainted node '$node' with workload=kafka:NoSchedule"
        else
            print_error "Failed to taint node '$node'"
        fi
    done
fi

# Next steps
echo ""
echo "========================================="
print_info "Next Steps:"
echo "========================================="
echo ""
echo "1. Deploy the node tuning DaemonSet (optional but recommended):"
echo "   kubectl apply -f infra/terraform/kubernetes/node-tuning-daemonset.yaml"
echo ""
echo "2. Deploy the Kafka cluster:"
echo "   kubectl apply -f platform/kafka/cluster.yaml"
echo ""
echo "3. Monitor pod scheduling:"
echo "   kubectl get pods -n kafka -o wide -w"
echo ""
echo "4. Verify pods are running on labeled nodes:"
echo "   kubectl get pods -n kafka -o wide | grep kafka-cluster-kafka"
echo ""

print_info "Labeling complete!"
