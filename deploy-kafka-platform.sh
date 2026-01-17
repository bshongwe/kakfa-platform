#!/bin/bash

# Kafka Platform Deployment Script
# This script deploys the complete Kafka platform to Kubernetes

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           🚀 KAFKA PLATFORM DEPLOYMENT AUTOMATION                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Phase 2: Verify Kubernetes is ready
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Phase 1: Kubernetes Cluster${NC} - Already running"
echo ""
kubectl cluster-info
echo ""

# Phase 3: Install Strimzi Operator
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⏳ Phase 3: Installing Strimzi Operator${NC}"
echo ""

# Create kafka namespace
if kubectl get namespace kafka &> /dev/null; then
    echo "✓ Kafka namespace already exists"
else
    kubectl create namespace kafka
    echo "✓ Created kafka namespace"
fi

# Install Strimzi operator
echo "📥 Installing Strimzi operator..."
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka 2>/dev/null || echo "✓ Strimzi operator already installed"

# Wait for operator to be ready
echo "⏳ Waiting for Strimzi operator to be ready (up to 5 minutes)..."
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s

echo -e "${GREEN}✓ Phase 3: Strimzi Operator installed and ready${NC}"
echo ""

# Phase 4: Deploy Kafka Cluster
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⏳ Phase 4: Deploying Kafka Cluster${NC}"
echo ""

kubectl apply -f platform/kafka/cluster.yaml -n kafka

echo "⏳ Waiting for Kafka cluster to be ready (up to 10 minutes)..."
echo "   This creates 3 Kafka brokers + 3 ZooKeeper nodes..."
kubectl wait kafka/fintech-kafka --for=condition=Ready --timeout=600s -n kafka

echo ""
echo "📊 Kafka pods status:"
kubectl get pods -n kafka
echo ""

echo -e "${GREEN}✓ Phase 4: Kafka Cluster deployed and ready${NC}"
echo ""

# Phase 5: Deploy Kafka Topics
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⏳ Phase 5: Deploying Kafka Topics${NC}"
echo ""

kubectl apply -f platform/topics/payments/ -n kafka
echo "✓ Payments topics created"

kubectl apply -f platform/topics/ledger/ -n kafka
echo "✓ Ledger topics created"

kubectl apply -f platform/topics/notifications/ -n kafka
echo "✓ Notifications topics created"

kubectl apply -f platform/topics/audit/ -n kafka
echo "✓ Audit topics created"

echo ""
echo "📊 Created topics:"
kubectl get kafkatopic -n kafka
echo ""

echo -e "${GREEN}✓ Phase 5: All Kafka topics deployed${NC}"
echo ""

# Phase 6: Deploy Kafka Users
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⏳ Phase 6: Deploying Kafka Users${NC}"
echo ""

kubectl apply -f platform/kafka/users/ -n kafka

echo "⏳ Waiting for users to be ready (TLS certificate generation)..."
sleep 10

echo ""
echo "📊 Created users:"
kubectl get kafkauser -n kafka
echo ""

echo "🔐 Generated secrets:"
kubectl get secrets -n kafka | grep "-service"
echo ""

echo -e "${GREEN}✓ Phase 6: All Kafka users deployed${NC}"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ KAFKA PLATFORM DEPLOYMENT COMPLETE!${NC}"
echo ""
echo "📊 Deployment Summary:"
echo "   ✓ Strimzi Operator running"
echo "   ✓ Kafka Cluster (3 brokers + 3 ZooKeeper)"
echo "   ✓ 12 Kafka topics created"
echo "   ✓ 4 Kafka users with TLS authentication"
echo ""
echo "🎯 Next Steps:"
echo "   1. Build and deploy microservices"
echo "   2. Configure GitHub secrets for CI/CD"
echo "   3. Test the platform end-to-end"
echo ""
echo "📝 Useful commands:"
echo "   kubectl get pods -n kafka                    # View all Kafka pods"
echo "   kubectl logs -f deployment/strimzi-cluster-operator -n kafka"
echo "   kubectl exec -it fintech-kafka-kafka-0 -n kafka -- bin/kafka-topics.sh --list --bootstrap-server localhost:9092"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
