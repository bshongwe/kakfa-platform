# Payments Service

Production-ready payment processing microservice with Kafka integration.

## Features

- ✅ **Event-Driven Architecture**: Kafka producer/consumer with transactional support
- ✅ **Type Safety**: Full TypeScript implementation with Zod validation
- ✅ **Observability**: Prometheus metrics, structured logging (Winston)
- ✅ **Health Checks**: Kubernetes-ready liveness/readiness probes
- ✅ **Security**: SASL/SCRAM authentication, non-root container, read-only filesystem
- ✅ **High Availability**: Horizontal scaling, graceful shutdown
- ✅ **Production Ready**: Error handling, audit logging, idempotent processing

## Architecture

```
┌─────────────────┐
│ Payment Request │
│  (Kafka Topic)  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│   Payments Service          │
│                             │
│  ┌────────────────────┐    │
│  │  Kafka Consumer    │    │
│  └─────────┬──────────┘    │
│            │                │
│  ┌─────────▼──────────┐    │
│  │ Payment Processor  │    │
│  └─────────┬──────────┘    │
│            │                │
│  ┌─────────▼──────────┐    │
│  │  Kafka Producer    │    │
│  └────────────────────┘    │
└─────────────────────────────┘
         │
         ├─────► payments.payment-processed (Success)
         ├─────► payments.payment-failed (Failure)
         └─────► audit.payment-events (Audit)
```

## Quick Start

### Local Development

1. **Install dependencies:**
```bash
npm install
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your Kafka credentials
```

3. **Run in development mode:**
```bash
npm run dev
```

4. **Build for production:**
```bash
npm run build
npm start
```

### Docker

```bash
# Build image
docker build -t payments-service:1.0.0 .

# Run container
docker run -p 3000:3000 -p 9090:9090 \
  --env-file .env \
  payments-service:1.0.0
```

### Kubernetes

```bash
# Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# Check status
kubectl get pods -n payments -l app=payments-service

# View logs
kubectl logs -n payments -l app=payments-service -f

# Check metrics
kubectl port-forward -n payments svc/payments-service 9090:9090
curl http://localhost:9090/metrics
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `KAFKA_BROKERS` | Kafka broker addresses (comma-separated) | Required |
| `KAFKA_SASL_USERNAME` | Kafka SASL username | Required |
| `KAFKA_SASL_PASSWORD` | Kafka SASL password | Required |
| `KAFKA_SASL_MECHANISM` | SASL mechanism | `SCRAM-SHA-512` |
| `PORT` | HTTP server port | `3000` |
| `METRICS_PORT` | Prometheus metrics port | `9090` |
| `LOG_LEVEL` | Logging level | `info` |
| `NODE_ENV` | Environment | `production` |

## API Endpoints

### Health Checks

- **GET `/health`** - Comprehensive health check (includes Kafka connectivity)
- **GET `/ready`** - Readiness probe for Kubernetes
- **GET `/live`** - Liveness probe for Kubernetes

### Metrics

- **GET `/metrics`** - Prometheus metrics endpoint

## Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `payments_processed_total` | Counter | Total successful payments |
| `payments_failed_total` | Counter | Total failed payments |
| `payment_processing_duration_seconds` | Histogram | Payment processing duration |
| `kafka_messages_total` | Counter | Total Kafka messages |

## Kafka Topics

### Input Topics

- **`payments.payment-requested`**: Incoming payment requests

```json
{
  "paymentId": "pay_123",
  "userId": "user_456",
  "amount": 99.99,
  "currency": "USD",
  "paymentMethod": "credit_card",
  "metadata": {
    "orderId": "order_789"
  }
}
```

### Output Topics

- **`payments.payment-processed`**: Successfully processed payments
- **`payments.payment-failed`**: Failed payment attempts
- **`audit.payment-events`**: Audit trail for all payments

## Testing

```bash
# Run tests
npm test

# Watch mode
npm run test:watch

# Coverage
npm run test:coverage

# Type checking
npm run typecheck

# Linting
npm run lint
npm run lint:fix
```

## Monitoring

### Prometheus Queries

```promql
# Payment success rate
rate(payments_processed_total[5m]) / (rate(payments_processed_total[5m]) + rate(payments_failed_total[5m]))

# Average payment processing time
rate(payment_processing_duration_seconds_sum[5m]) / rate(payment_processing_duration_seconds_count[5m])

# Kafka message throughput
rate(kafka_messages_total{status="success"}[5m])
```

### Grafana Dashboard

Import the Grafana dashboard from `grafana/dashboard.json` for pre-built visualizations.

## Security

- ✅ Non-root container user (UID 1001)
- ✅ Read-only root filesystem
- ✅ Dropped all capabilities
- ✅ SASL/SCRAM authentication for Kafka
- ✅ TLS encryption for Kafka connections
- ✅ Secret management via Kubernetes secrets

## Production Considerations

1. **Scaling**: Adjust `replicas` in `k8s/deployment.yaml` based on load
2. **Resources**: Tune CPU/memory limits based on traffic patterns
3. **Monitoring**: Set up alerts for failed payments and high latency
4. **Secrets**: Use external secret managers (HashiCorp Vault, AWS Secrets Manager)
5. **Schema Registry**: Enable Avro schemas for backward compatibility

## Troubleshooting

### Service won't start

```bash
# Check Kafka connectivity
kubectl exec -it -n payments deployment/payments-service -- sh
curl kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092

# Check logs
kubectl logs -n payments -l app=payments-service --tail=100

# Check environment variables
kubectl exec -it -n payments deployment/payments-service -- env | grep KAFKA
```

### High error rate

```bash
# Check metrics
kubectl port-forward -n payments svc/payments-service 9090:9090
curl http://localhost:9090/metrics | grep payments_failed_total

# Check Kafka consumer lag
kubectl exec -it -n kafka kafka-cluster-kafka-0 -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group payments-service-group
```

## License

MIT
