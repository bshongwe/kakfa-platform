# Notification Service

Multi-channel notification delivery service supporting email, SMS, push, and webhooks.

## Features

- ✅ **Multi-Channel**: Email, SMS, Push, Webhook support
- ✅ **Template Support**: Configurable notification templates
- ✅ **Retry Logic**: Automatic retry for failed deliveries
- ✅ **Delivery Tracking**: Track notification delivery status
- ✅ **Provider Abstraction**: Easy integration with notification providers

## Topics

### Input:
- `notifications.notification-requested` - Notification delivery requests
- `payments.payment-processed` - Payment confirmation triggers
- `payments.payment-failed` - Payment failure notifications

### Output:
- `notifications.notification-sent` - Successfully sent notifications
- `notifications.notification-failed` - Failed delivery attempts
- `audit.notification-events` - Audit trail for notifications

## Notification Types

### Email
- Payment confirmations
- Account alerts
- Receipt delivery

### SMS
- Two-factor authentication
- Payment alerts
- Critical notifications

### Push Notifications
- Mobile app alerts
- Real-time updates

### Webhooks
- External system integrations
- API callbacks

## Quick Start

```bash
npm install
npm run dev
```

## Docker

```bash
docker build -t notifications-service:1.0.0 .
docker run -p 3000:3000 -p 9090:9090 --env-file .env notifications-service:1.0.0
```

## Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -n notifications -l app=notifications-service
```

## Provider Integration

In production, integrate with:
- **Email**: SendGrid, AWS SES, Mailgun
- **SMS**: Twilio, AWS SNS, Vonage
- **Push**: Firebase Cloud Messaging, Apple Push Notification Service
- **Webhooks**: Custom HTTP clients with retry logic
