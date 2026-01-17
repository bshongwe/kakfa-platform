# Kafka Platform Microservices

Event-driven microservices architecture built on Apache Kafka with TypeScript/Node.js.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Kafka Cluster                              │
│                  (Event Streaming Platform)                         │
└───────────┬─────────────────┬─────────────────┬────────────────────┘
            │                 │                 │
            │                 │                 │
┌───────────▼──────┐  ┌──────▼─────────┐  ┌───▼──────────────┐
│   Payments       │  │   Ledger       │  │  Notifications   │
│   Service        │  │   Service      │  │  Service         │
│                  │  │                │  │                  │
│ • Process        │  │ • Track        │  │ • Send emails    │
│   payments       │  │   balances     │  │ • Send SMS       │
│ • Validate       │  │ • Double-entry │  │ • Push notifs    │
│ • Settle         │  │   bookkeeping  │  │ • Webhooks       │
└──────────────────┘  └────────────────┘  └──────────────────┘
            │                 │                 │
            └─────────────────┼─────────────────┘
                              │
                     ┌────────▼──────────┐
                     │   Audit Service   │
                     │                   │
                     │ • Compliance      │
                     │ • Event logging   │
                     │ • 7-year retention│
                     └───────────────────┘
```

## 📦 Services

### 1. Payments Service
**Purpose**: Process payment transactions and settlement

**Topics**:
- **Consumes**: `payments.payment-requested`
- **Produces**: `payments.payment-processed`, `payments.payment-failed`, `audit.payment-events`

**Features**:
- Payment processing (credit cards, ACH, etc.)
- Transaction validation
- Fraud detection integration points
- Idempotent processing
- 95%+ success rate

[**Full Documentation →**](./payments/README.md)

---

### 2. Ledger Service
**Purpose**: Maintain account balances with double-entry bookkeeping

**Topics**:
- **Consumes**: `ledger.transaction-requested`, `payments.payment-processed`
- **Produces**: `ledger.balance-updated`, `audit.ledger-events`

**Features**:
- Real-time balance tracking
- Multi-currency support
- Transaction history
- Balance validation
- Consistency guarantees

[**Full Documentation →**](./ledger/README.md)

---

### 3. Notifications Service
**Purpose**: Multi-channel notification delivery

**Topics**:
- **Consumes**: `notifications.notification-requested`, `payments.payment-processed`, `payments.payment-failed`
- **Produces**: `notifications.notification-sent`, `notifications.notification-failed`, `audit.notification-events`

**Features**:
- Email notifications (SendGrid, AWS SES)
- SMS notifications (Twilio, AWS SNS)
- Push notifications (Firebase, APNS)
- Webhook delivery
- Template management
- Delivery tracking

[**Full Documentation →**](./notifications/README.md)

---

### 4. Audit Service
**Purpose**: Centralized audit logging and compliance monitoring

**Topics**:
- **Consumes**: `audit.*` (all audit topics)
- **Produces**: `audit.compliance-alerts`

**Features**:
- 7+ year event retention
- Compliance violation detection
- High-value transaction monitoring
- Failed authentication tracking
- Query API for audit logs
- Tamper-proof logging

[**Full Documentation →**](./audit/README.md)

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- npm 9+
- Kafka cluster (Strimzi on Kubernetes)
- Kubernetes cluster (for deployment)

### Development Setup

```bash
# Install dependencies for all services
cd payments && npm install && cd ..
cd ledger && npm install && cd ..
cd notifications && npm install && cd ..
cd audit && npm install && cd ..
```

### Run Services Locally

```bash
# Terminal 1 - Payments
cd payments
npm run dev

# Terminal 2 - Ledger
cd ledger
npm run dev

# Terminal 3 - Notifications
cd notifications
npm run dev

# Terminal 4 - Audit
cd audit
npm run dev
```

### Build All Services

```bash
# Build all services
for service in payments ledger notifications audit; do
  echo "Building $service..."
  cd $service
  npm run build
  cd ..
done
```

### Docker Build

```bash
# Build Docker images
docker build -t payments-service:1.0.0 ./payments
docker build -t ledger-service:1.0.0 ./ledger
docker build -t notifications-service:1.0.0 ./notifications
docker build -t audit-service:1.0.0 ./audit
```

### Kubernetes Deployment

```bash
# Deploy all services
kubectl apply -f payments/k8s/deployment.yaml
kubectl apply -f ledger/k8s/deployment.yaml
kubectl apply -f notifications/k8s/deployment.yaml
kubectl apply -f audit/k8s/deployment.yaml

# Check status
kubectl get pods -n payments -l app=payments-service
kubectl get pods -n ledger -l app=ledger-service
kubectl get pods -n notifications -l app=notifications-service
kubectl get pods -n audit -l app=audit-service
```

---

## 📊 Event Flow Example

### Payment Processing Flow

```
1. Payment Request
   ├─► payments.payment-requested
   │
2. Payments Service processes
   ├─► payments.payment-processed (success)
   └─► payments.payment-failed (failure)
   │
3. Ledger Service updates balance
   ├─► ledger.balance-updated
   │
4. Notifications Service sends confirmation
   ├─► notifications.notification-sent
   │
5. Audit Service logs everything
   └─► audit.payment-events
       audit.ledger-events
       audit.notification-events
```

### Sample Event

```json
{
  "paymentId": "pay_abc123",
  "userId": "user_456",
  "amount": 99.99,
  "currency": "USD",
  "paymentMethod": "credit_card",
  "timestamp": "2026-01-17T21:00:00Z",
  "metadata": {
    "orderId": "order_789",
    "description": "Product purchase"
  }
}
```

---

## 📈 Monitoring & Observability

### Health Checks

All services expose:
- **`GET /health`** - Comprehensive health check
- **`GET /ready`** - Kubernetes readiness probe
- **`GET /live`** - Kubernetes liveness probe

### Metrics (Prometheus)

All services expose:
- **`GET /metrics`** - Prometheus metrics (port 9090)

**Common Metrics**:
- `kafka_messages_total` - Total Kafka messages processed
- Service-specific counters and histograms

**Payments**:
- `payments_processed_total` - Successful payments
- `payments_failed_total` - Failed payments
- `payment_processing_duration_seconds` - Processing latency

### Logging

All services use structured JSON logging (Winston):
```json
{
  "timestamp": "2026-01-17T21:00:00Z",
  "level": "info",
  "service": "payments-service",
  "message": "Payment processed successfully",
  "paymentId": "pay_abc123",
  "amount": 99.99
}
```

### Grafana Dashboards

Import pre-built dashboards from `/observability/grafana/` for:
- Service health and uptime
- Kafka message throughput
- Error rates and latency
- Business metrics (payment volume, etc.)

---

## 🔒 Security

### Authentication
- Kafka SASL/SCRAM-SHA-512 authentication
- TLS encryption for all Kafka connections
- Kubernetes secrets for credentials

### Container Security
- Non-root user (UID 1001)
- Read-only root filesystem
- Dropped all capabilities
- Security contexts enforced

### Network Security
- Network policies for namespace isolation
- Service mesh integration (optional: Istio/Linkerd)
- mTLS between services

---

## 🧪 Testing

### Unit Tests
```bash
cd payments
npm test
npm run test:coverage
```

### Integration Tests
```bash
# Start test Kafka cluster
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
npm run test:integration
```

### End-to-End Tests
```bash
# Deploy to staging environment
kubectl apply -f k8s/ --namespace=staging

# Run E2E test suite
npm run test:e2e
```

---

## 📝 Development Guidelines

### Code Standards
- TypeScript strict mode
- ESLint + Prettier formatting
- 80%+ test coverage
- Comprehensive JSDoc comments

### Kafka Best Practices
- Exactly-once semantics for critical flows
- Idempotent producers
- Consumer group management
- Dead letter queues for failed messages
- Schema evolution with Avro

### Deployment
- Blue-green deployments
- Canary releases (10% → 50% → 100%)
- Automated rollback on errors
- Zero-downtime deployments

---

## 🛠️ Troubleshooting

### Service Won't Start

```bash
# Check Kafka connectivity
kubectl exec -it -n payments deployment/payments-service -- sh
nc -zv kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local 9092

# Check logs
kubectl logs -n payments -l app=payments-service --tail=100 -f

# Check environment variables
kubectl describe pod -n payments -l app=payments-service
```

### High Consumer Lag

```bash
# Check consumer group lag
kubectl exec -it -n kafka kafka-cluster-kafka-0 -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group payments-service-group

# Scale up replicas
kubectl scale deployment/payments-service --replicas=5 -n payments
```

### Message Processing Errors

```bash
# Check dead letter queue
kubectl exec -it -n kafka kafka-cluster-kafka-0 -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic payments.dlq \
  --from-beginning

# View error metrics
kubectl port-forward -n payments svc/payments-service 9090:9090
curl http://localhost:9090/metrics | grep error
```

---

## 📚 Additional Resources

- [Kafka Platform README](../README.md) - Overall platform documentation
- [OPA Policies](../policies/opa/README.md) - Governance rules
- [Chaos Engineering](../chaos/README.md) - Resilience testing
- [Runbooks](../runbooks/) - Operational procedures
- [SLO Documentation](../slo/README.md) - Service level objectives

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`npm test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

---

## 📄 License

MIT License - see [LICENSE](../LICENSE) for details

---

## 📞 Support

- **Slack**: `#kafka-platform`
- **Email**: kafka-platform-team@company.com
- **On-call**: PagerDuty rotation

---

**Built with ❤️ by the Kafka Platform Team**
