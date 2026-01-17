# Audit Service

Centralized audit logging service for compliance and security monitoring.

## Features

- ✅ **Centralized Logging**: Collect audit events from all services
- ✅ **Compliance Monitoring**: Automated compliance violation detection
- ✅ **Event Storage**: Persistent audit trail (7+ years retention)
- ✅ **Query API**: Search and retrieve audit logs
- ✅ **Alerting**: Real-time compliance alerts

## Topics

### Input:
- `audit.payment-events` - Payment system events
- `audit.ledger-events` - Ledger transaction events
- `audit.notification-events` - Notification delivery events
- `audit.system-events` - System-level events

### Output:
- `audit.compliance-alerts` - Compliance violation alerts

## Compliance Rules

- High-value transactions (>$10,000)
- Failed authentication attempts
- Unauthorized access attempts
- Data export events
- Configuration changes

## Quick Start

```bash
npm install
npm run dev
```

## Docker

```bash
docker build -t audit-service:1.0.0 .
docker run -p 3000:3000 -p 9090:9090 --env-file .env audit-service:1.0.0
```

## Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -n audit -l app=audit-service
```

## Production Considerations

- Store events in database/data lake (not in-memory)
- Implement retention policies (7-year minimum for financial data)
- Archive old events to cold storage
- Enable encryption at rest and in transit
- Implement access controls for audit log queries
