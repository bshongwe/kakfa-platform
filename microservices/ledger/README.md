# Ledger Service

Transaction ledger microservice for maintaining account balances with double-entry bookkeeping.

## Features

- ✅ **Double-Entry Bookkeeping**: Maintain accurate account balances
- ✅ **Real-time Processing**: Kafka event-driven updates
- ✅ **Balance Tracking**: Track account balances per currency
- ✅ **Audit Trail**: Complete audit logging for compliance
- ✅ **High Availability**: Stateless service with external state management

## Topics

### Input:
- `ledger.transaction-requested` - Incoming transaction requests
- `payments.payment-processed` - Payment completion events

### Output:
- `ledger.balance-updated` - Balance change notifications
- `audit.ledger-events` - Audit trail events

## Quick Start

```bash
npm install
npm run dev
```

## Docker

```bash
docker build -t ledger-service:1.0.0 .
docker run -p 3000:3000 -p 9090:9090 --env-file .env ledger-service:1.0.0
```

## Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -n ledger -l app=ledger-service
```
