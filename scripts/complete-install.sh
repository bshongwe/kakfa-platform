#!/bin/bash

# Complete Kafka Platform Installation Script
# This script automates the entire installation process

set -e

# Default options
INSTALL_MONITORING=false
SKIP_TUNING=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

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

print_success() {
    echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

# Parse arguments
NODES=()
for arg in "$@"; do
    case $arg in
        --with-monitoring)
            INSTALL_MONITORING=true
            shift
            ;;
        --skip-tuning)
            SKIP_TUNING=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS] <node1> <node2> <node3> ..."
            echo ""
            echo "Options:"
            echo "  --with-monitoring    Install Prometheus and Grafana"
            echo "  --skip-tuning        Skip node tuning DaemonSet"
            echo "  --help               Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --with-monitoring node-1 node-2 node-3"
            exit 0
            ;;
        *)
            NODES+=("$arg")
            ;;
    esac
done

# Validate inputs
if [ ${#NODES[@]} -eq 0 ]; then
    print_error "No nodes specified. Please provide at least one node name."
    echo ""
    echo "Usage: $0 [OPTIONS] <node1> <node2> <node3> ..."
    echo "Run '$0 --help' for more information"
    exit 1
fi

if [ ${#NODES[@]} -lt 3 ]; then
    print_warning "Less than 3 nodes specified. For production, use at least 3 nodes."
fi

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

echo ""
echo "========================================="
echo "  Kafka Platform Complete Installation"
echo "========================================="
echo ""
print_info "Configuration:"
echo "  - Nodes: ${NODES[*]}"
echo "  - Install Monitoring: $INSTALL_MONITORING"
echo "  - Skip Tuning: $SKIP_TUNING"
echo ""
read -p "Continue with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 0
fi
echo ""

# Step 1: Install Strimzi Operator
print_step "Step 1/8 - Installing Strimzi Kafka Operator"
./scripts/install-strimzi.sh
echo ""

# Step 2: Label nodes
print_step "Step 2/8 - Labeling Kubernetes nodes for Kafka"
./scripts/label-kafka-nodes.sh "${NODES[@]}"
echo ""

# Step 3: Node tuning (optional)
if [ "$SKIP_TUNING" = false ]; then
    print_step "Step 3/8 - Applying node tuning optimizations"
    kubectl apply -f infra/terraform/kubernetes/node-tuning-daemonset.yaml
    print_info "Node tuning DaemonSet deployed"
else
    print_step "Step 3/8 - Skipping node tuning (--skip-tuning specified)"
fi
echo ""

# Step 4: Create metrics ConfigMap
print_step "Step 4/8 - Creating Kafka metrics ConfigMap"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-metrics
  namespace: kafka
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
      name: kafka_server_\$1_\$2
      type: GAUGE
      labels:
        clientId: "\$3"
        topic: "\$4"
        partition: "\$5"
  zookeeper-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: "org.apache.ZooKeeperService<name0=(.+)><>(.+)"
      name: "zookeeper_\$2"
EOF
print_info "Metrics ConfigMap created"
echo ""

# Step 5: Deploy Kafka cluster
print_step "Step 5/8 - Deploying Kafka cluster (this may take 5-10 minutes)"
kubectl apply -f platform/kafka/cluster.yaml
print_info "Kafka cluster deployment initiated"
print_info "Waiting for Kafka cluster to be ready..."

if kubectl wait kafka/kafka-cluster --for=condition=Ready --timeout=600s -n kafka 2>/dev/null; then
    print_success "Kafka cluster is ready!"
else
    print_warning "Timeout waiting for Kafka cluster. It may still be deploying."
    print_info "Check status with: kubectl get kafka -n kafka"
fi
echo ""

# Step 6: Create topics
print_step "Step 6/8 - Creating Kafka topics"
kubectl apply -f platform/kafka/topics/
print_info "Topics created"
echo ""

# Step 7: Create users
print_step "Step 7/8 - Creating Kafka users with ACLs"
kubectl apply -f platform/kafka/users/
print_info "Users created"
echo ""

# Step 8: Deploy Schema Registry
print_step "Step 8/8 - Deploying Schema Registry"
kubectl apply -f platform/schema-registry/schema-registry.yaml
print_info "Schema Registry deployed"
echo ""

# Optional: Install monitoring
if [ "$INSTALL_MONITORING" = true ]; then
    echo ""
    print_step "Installing Monitoring Stack (Prometheus + Grafana)"
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Prometheus PVC
    print_info "Creating Prometheus storage..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF
    
    # Deploy Prometheus
    kubectl apply -f observability/prometheus/prometheus.yaml
    
    # Grafana secret
    print_info "Creating Grafana admin secret..."
    kubectl create secret generic grafana-admin \
      --from-literal=password=admin123 \
      -n monitoring \
      --dry-run=client -o yaml | kubectl apply -f -
    
    # Grafana PVC
    print_info "Creating Grafana storage..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
    
    # Grafana dashboard config
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-config
  namespace: monitoring
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: 'Kafka'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards
EOF
    
    # Deploy Grafana
    kubectl apply -f observability/grafana/grafana.yaml
    
    # Deploy alerts
    kubectl apply -f observability/alerts/kafka-alerts.yaml
    
    print_success "Monitoring stack deployed!"
fi

# Final summary
echo ""
echo "========================================="
print_success "Installation Complete!"
echo "========================================="
echo ""
print_info "Kafka Platform Status:"
echo ""

# Show Kafka status
echo "Kafka Cluster:"
kubectl get kafka -n kafka 2>/dev/null || echo "  Status: Deploying..."
echo ""

echo "Kafka Pods:"
kubectl get pods -n kafka -o wide 2>/dev/null | grep -E "NAME|kafka-cluster" || echo "  Pods are starting..."
echo ""

echo "Topics:"
kubectl get kafkatopic -n kafka 2>/dev/null || echo "  No topics yet"
echo ""

echo "Users:"
kubectl get kafkauser -n kafka 2>/dev/null || echo "  No users yet"
echo ""

# Connection info
echo "========================================="
print_info "Connection Information:"
echo "========================================="
echo ""
echo "Kafka Bootstrap Server (internal):"
echo "  kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
echo ""
echo "Schema Registry (internal):"
echo "  http://schema-registry.kafka.svc.cluster.local:8081"
echo ""

if [ "$INSTALL_MONITORING" = true ]; then
    echo "Grafana:"
    GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$GRAFANA_IP" ]; then
        echo "  http://$GRAFANA_IP:3000"
    else
        echo "  Run: kubectl port-forward svc/grafana 3000:3000 -n monitoring"
        echo "  Then access: http://localhost:3000"
    fi
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
fi

# Next steps
echo "========================================="
print_info "Next Steps:"
echo "========================================="
echo ""
echo "1. Test Kafka with a producer:"
echo "   kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \\"
echo "     --rm=true --restart=Never -n kafka -- \\"
echo "     bin/kafka-console-producer.sh \\"
echo "     --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \\"
echo "     --topic example-topic"
echo ""
echo "2. Test Kafka with a consumer:"
echo "   kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \\"
echo "     --rm=true --restart=Never -n kafka -- \\"
echo "     bin/kafka-console-consumer.sh \\"
echo "     --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \\"
echo "     --topic example-topic --from-beginning"
echo ""
echo "3. Monitor the cluster:"
echo "   kubectl get kafka,kafkatopic,kafkauser -n kafka"
echo ""
echo "4. View logs:"
echo "   kubectl logs kafka-cluster-kafka-0 -n kafka"
echo ""
echo "For more information, see:"
echo "  - docs/MANUAL_INSTALLATION.md"
echo "  - docs/GETTING_STARTED.md"
echo "  - docs/ARCHITECTURE.md"
echo ""
print_success "Happy Kafka-ing! 🎉"
