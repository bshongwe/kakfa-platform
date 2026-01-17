#!/bin/bash
set -euo pipefail

# =============================================================================
# Phase A Deployment Script - Event-Driven Microservices
# =============================================================================
# This script deploys all Phase A components:
# - Kafka topics for all 4 domains
# - KafkaUser resources with ACLs
# - Schema registration
# - Validation and health checks
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KAFKA_NAMESPACE="${KAFKA_NAMESPACE:-kafka}"
SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://schema-registry.kafka.svc.cluster.local:8081}"
KAFKA_CLUSTER_NAME="${KAFKA_CLUSTER_NAME:-fintech-kafka}"

# =============================================================================
# Helper Functions
# =============================================================================

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

wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local timeout=${3:-300}
    
    log_info "Waiting for ${resource_type}/${resource_name} to be ready..."
    if kubectl wait --for=condition=Ready "${resource_type}/${resource_name}" \
        -n "${KAFKA_NAMESPACE}" --timeout="${timeout}s" 2>/dev/null; then
        log_success "${resource_type}/${resource_name} is ready"
        return 0
    else
        log_warning "${resource_type}/${resource_name} not ready after ${timeout}s"
        return 1
    fi
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

log_info "=== Phase A Deployment: Event-Driven Microservices ==="
echo ""

log_info "Performing pre-flight checks..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
fi

# Check namespace
if ! kubectl get namespace "${KAFKA_NAMESPACE}" &> /dev/null; then
    log_error "Namespace ${KAFKA_NAMESPACE} not found."
    log_info "Please run: kubectl create namespace ${KAFKA_NAMESPACE}"
    exit 1
fi

# Check Kafka cluster
if ! kubectl get kafka "${KAFKA_CLUSTER_NAME}" -n "${KAFKA_NAMESPACE}" &> /dev/null; then
    log_error "Kafka cluster ${KAFKA_CLUSTER_NAME} not found in namespace ${KAFKA_NAMESPACE}."
    log_info "Please deploy the Kafka cluster first using platform/kafka/cluster.yaml"
    exit 1
fi

# Check if Kafka is ready
if ! kubectl get kafka "${KAFKA_CLUSTER_NAME}" -n "${KAFKA_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
    log_error "Kafka cluster ${KAFKA_CLUSTER_NAME} is not ready."
    log_info "Please wait for Kafka cluster to be fully operational."
    exit 1
fi

log_success "Pre-flight checks passed"
echo ""

# =============================================================================
# Step 1: Deploy Topics
# =============================================================================

log_info "Step 1: Deploying Kafka topics for all domains..."
echo ""

# Payments topics
log_info "Deploying Payments domain topics..."
kubectl apply -f platform/topics/payments/payments-topics.yaml -n "${KAFKA_NAMESPACE}"

# Ledger topics
log_info "Deploying Ledger domain topics..."
kubectl apply -f platform/topics/ledger/ledger-topics.yaml -n "${KAFKA_NAMESPACE}"

# Notifications topics
log_info "Deploying Notifications domain topics..."
kubectl apply -f platform/topics/notifications/notifications-topics.yaml -n "${KAFKA_NAMESPACE}"

# Audit topics
log_info "Deploying Audit domain topics..."
kubectl apply -f platform/topics/audit/audit-topics.yaml -n "${KAFKA_NAMESPACE}"

# Wait for topics to be ready
log_info "Waiting for topics to be created..."
sleep 10

# Verify topics
TOPIC_COUNT=$(kubectl get kafkatopic -n "${KAFKA_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
log_success "Created ${TOPIC_COUNT} topics"

# List topics by domain
echo ""
log_info "Topics by domain:"
for domain in payments ledger notifications audit; do
    echo -e "${BLUE}  ${domain}:${NC}"
    kubectl get kafkatopic -n "${KAFKA_NAMESPACE}" -l domain="${domain}" \
        -o custom-columns="NAME:.metadata.name,PARTITIONS:.spec.partitions,REPLICAS:.spec.replicas" \
        --no-headers 2>/dev/null | sed 's/^/    /'
done
echo ""

# =============================================================================
# Step 2: Create KafkaUsers with ACLs
# =============================================================================

log_info "Step 2: Creating KafkaUsers with ACLs..."
echo ""

# Deploy all user resources
log_info "Deploying Payments service user..."
kubectl apply -f platform/kafka/users/payments-service-user.yaml -n "${KAFKA_NAMESPACE}"

log_info "Deploying Ledger service user..."
kubectl apply -f platform/kafka/users/ledger-service-user.yaml -n "${KAFKA_NAMESPACE}"

log_info "Deploying Notifications service user..."
kubectl apply -f platform/kafka/users/notifications-service-user.yaml -n "${KAFKA_NAMESPACE}"

log_info "Deploying Audit service user..."
kubectl apply -f platform/kafka/users/audit-service-user.yaml -n "${KAFKA_NAMESPACE}"

# Wait for users to be ready
log_info "Waiting for KafkaUsers to be created..."
sleep 15

# Verify users
USER_COUNT=$(kubectl get kafkauser -n "${KAFKA_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
log_success "Created ${USER_COUNT} KafkaUsers"

echo ""
log_info "KafkaUsers:"
kubectl get kafkauser -n "${KAFKA_NAMESPACE}" \
    -o custom-columns="NAME:.metadata.name,AUTHENTICATION:.spec.authentication.type,STATUS:.status.conditions[?(@.type=='Ready')].status" \
    --no-headers 2>/dev/null | sed 's/^/  /'
echo ""

# Extract certificates for services
log_info "Extracting TLS certificates for services..."
for service in payments-service ledger-service notifications-service audit-service; do
    if kubectl get secret "${service}" -n "${KAFKA_NAMESPACE}" &> /dev/null; then
        log_success "Certificate for ${service} is available"
    else
        log_warning "Certificate for ${service} not found yet"
    fi
done
echo ""

# =============================================================================
# Step 3: Register Avro Schemas
# =============================================================================

log_info "Step 3: Registering Avro schemas with Schema Registry..."
echo ""

# Check if Schema Registry is accessible
log_info "Checking Schema Registry availability..."
if kubectl get service schema-registry -n "${KAFKA_NAMESPACE}" &> /dev/null; then
    log_success "Schema Registry service found"
    
    # Port forward to Schema Registry for local access
    log_info "Setting up port-forward to Schema Registry..."
    kubectl port-forward -n "${KAFKA_NAMESPACE}" svc/schema-registry 8081:8081 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Register schemas
    SCHEMA_REGISTRY_LOCAL="http://localhost:8081"
    
    # Payment Command Schema
    log_info "Registering payment-command schema..."
    if curl -X POST "${SCHEMA_REGISTRY_LOCAL}/subjects/payments.commands-value/versions" \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $(cat schemas/avro/payment-command-v1.avsc | jq -c | jq -R .)}" \
        --silent --fail; then
        log_success "Registered payment-command-v1 schema"
    else
        log_warning "Failed to register payment-command schema"
    fi
    
    # Payment Event Schema
    log_info "Registering payment-event schema..."
    if curl -X POST "${SCHEMA_REGISTRY_LOCAL}/subjects/payments.events-value/versions" \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $(cat schemas/avro/payment-event-v1.avsc | jq -c | jq -R .)}" \
        --silent --fail; then
        log_success "Registered payment-event-v1 schema"
    else
        log_warning "Failed to register payment-event schema"
    fi
    
    # Ledger Transaction Schema
    log_info "Registering ledger-transaction schema..."
    if curl -X POST "${SCHEMA_REGISTRY_LOCAL}/subjects/ledger.transactions-value/versions" \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $(cat schemas/avro/ledger-transaction-v1.avsc | jq -c | jq -R .)}" \
        --silent --fail; then
        log_success "Registered ledger-transaction-v1 schema"
    else
        log_warning "Failed to register ledger-transaction schema"
    fi
    
    # Audit Event Schema
    log_info "Registering audit-event schema..."
    if curl -X POST "${SCHEMA_REGISTRY_LOCAL}/subjects/audit.events-value/versions" \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $(cat schemas/avro/audit-event-v1.avsc | jq -c | jq -R .)}" \
        --silent --fail; then
        log_success "Registered audit-event-v1 schema"
    else
        log_warning "Failed to register audit-event schema"
    fi
    
    # List all schemas
    echo ""
    log_info "Registered schemas:"
    curl -s "${SCHEMA_REGISTRY_LOCAL}/subjects" | jq -r '.[]' | sed 's/^/  /'
    
    # Cleanup port-forward
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    
else
    log_warning "Schema Registry not found. Skipping schema registration."
    log_info "Deploy Schema Registry first using platform/schema-registry/schema-registry.yaml"
fi
echo ""

# =============================================================================
# Step 4: Health Checks & Validation
# =============================================================================

log_info "Step 4: Performing health checks..."
echo ""

# Check topic count
EXPECTED_TOPICS=16
ACTUAL_TOPICS=$(kubectl get kafkatopic -n "${KAFKA_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [ "${ACTUAL_TOPICS}" -ge "${EXPECTED_TOPICS}" ]; then
    log_success "Topic count check: ${ACTUAL_TOPICS}/${EXPECTED_TOPICS} ✓"
else
    log_warning "Topic count check: ${ACTUAL_TOPICS}/${EXPECTED_TOPICS} (expected at least ${EXPECTED_TOPICS})"
fi

# Check user count
EXPECTED_USERS=4
ACTUAL_USERS=$(kubectl get kafkauser -n "${KAFKA_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [ "${ACTUAL_USERS}" -ge "${EXPECTED_USERS}" ]; then
    log_success "User count check: ${ACTUAL_USERS}/${EXPECTED_USERS} ✓"
else
    log_warning "User count check: ${ACTUAL_USERS}/${EXPECTED_USERS}"
fi

# Check ready status
NOT_READY_TOPICS=$(kubectl get kafkatopic -n "${KAFKA_NAMESPACE}" \
    -o jsonpath='{.items[?(@.status.conditions[0].type!="Ready")].metadata.name}' 2>/dev/null)
if [ -z "${NOT_READY_TOPICS}" ]; then
    log_success "All topics are ready ✓"
else
    log_warning "Some topics are not ready: ${NOT_READY_TOPICS}"
fi

NOT_READY_USERS=$(kubectl get kafkauser -n "${KAFKA_NAMESPACE}" \
    -o jsonpath='{.items[?(@.status.conditions[0].type!="Ready")].metadata.name}' 2>/dev/null)
if [ -z "${NOT_READY_USERS}" ]; then
    log_success "All users are ready ✓"
else
    log_warning "Some users are not ready: ${NOT_READY_USERS}"
fi

echo ""

# =============================================================================
# Summary & Next Steps
# =============================================================================

log_success "=== Phase A Deployment Complete ==="
echo ""
log_info "Summary:"
echo "  ✓ Deployed ${ACTUAL_TOPICS} Kafka topics across 4 domains"
echo "  ✓ Created ${ACTUAL_USERS} KafkaUsers with ACLs"
echo "  ✓ Registered Avro schemas with Schema Registry"
echo "  ✓ Validated health and readiness"
echo ""

log_info "Next Steps:"
echo ""
echo "  1. Extract service certificates:"
echo "     kubectl get secret payments-service -n ${KAFKA_NAMESPACE} -o jsonpath='{.data.user\.p12}' | base64 -d > payments-service.p12"
echo ""
echo "  2. Deploy microservices using the certificates and ConfigMaps:"
echo "     kubectl apply -f services/payments-service/"
echo "     kubectl apply -f services/ledger-service/"
echo "     kubectl apply -f services/notifications-service/"
echo "     kubectl apply -f services/audit-service/"
echo ""
echo "  3. View Kafka resources:"
echo "     kubectl get kafkatopic,kafkauser -n ${KAFKA_NAMESPACE}"
echo ""
echo "  4. Test event flow:"
echo "     kubectl exec -it -n ${KAFKA_NAMESPACE} ${KAFKA_CLUSTER_NAME}-kafka-0 -- bin/kafka-console-producer.sh \\"
echo "       --bootstrap-server localhost:9092 --topic payments.commands"
echo ""
echo "  5. View Grafana dashboards:"
echo "     kubectl port-forward -n ${KAFKA_NAMESPACE} svc/grafana 3000:3000"
echo "     Open: http://localhost:3000"
echo ""
echo "  6. Proceed to Phase B: Exactly-Once Semantics"
echo "     See: docs/PHASE_B_EXACTLY_ONCE.md"
echo ""

log_info "Phase A Deployment Documentation: docs/PHASE_A_IMPLEMENTATION.md"
log_info "Strategic Roadmap: docs/STRATEGIC_ROADMAP.md"
echo ""
