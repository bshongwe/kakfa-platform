# Kafka Platform - Enterprise Fintech Event Streaming

A production-ready, enterprise-grade Kafka platform for financial services with event-driven microservices, exactly-once semantics, and multi-region disaster recovery.

## 🎯 Overview

This platform implements a **5-phase strategic roadmap** + **10 enterprise maturity requirements** for building a world-class event streaming infrastructure:

### Enterprise Maturity (Production-Ready)
- 🔄 **1. Chaos Engineering** - Break it on purpose
- 🔄 **2. SLOs & Error Budgets** - Reliability contracts
- 📋 **3. Platform Governance** - Kafka CoE
- 📋 **4. Data Lifecycle Management** - Tiered storage & cleanup
- 📋 **5. Replay & Time Travel** - Event replay infrastructure
- 📋 **6. Abuse Prevention** - Quotas & guardrails
- 🔄 **7. Incident Runbooks** - 03:12 AM readiness
- 📋 **8. Platform APIs** - Self-service automation
- 📋 **9. Compliance & Audit** - Regulatory readiness
- 📋 **10. Scale Validation** - 500k+ msg/sec proof

### Key Features

- 🔐 **Enterprise Security**: TLS authentication, fine-grained ACLs, resource quotas
- 📈 **High Availability**: 3-broker cluster, min.insync.replicas, rack awareness
- 💾 **Regulatory Compliance**: 7-10 year retention for audit trails, infinite retention for ledger
- 🎯 **Exactly-Once Ready**: All services configured for Phase B implementation
- 📊 **Observability**: JMX metrics, Prometheus integration, Grafana dashboards

## 📂 Structure

```
kakfa-platform/
├── microservices/                    # ✅ Event-driven microservices (NEW!)
│   ├── payments/                     # Payment processing service
│   ├── ledger/                       # Account balance & transactions
│   ├── notifications/                # Multi-channel notifications
│   ├── audit/                        # Compliance & audit logging
│   └── README.md                     # Full architecture documentation
├── docs/                              # Complete documentation
│   ├── STRATEGIC_ROADMAP.md          # 5-phase fintech roadmap
│   ├── PHASE_A_IMPLEMENTATION.md     # Detailed Phase A guide
│   ├── PHASE_B_EXACTLY_ONCE.md       # Next: Exactly-once semantics
│   ├── MICROSERVICES_IMPLEMENTATION.md  # ✅ Microservices guide (NEW!)
│   └── INSTALLATION_METHODS.md       # Installation approaches
├── platform/
│   ├── kafka/
│   │   ├── cluster.yaml              # 3-broker Kafka cluster
│   │   └── users/                    # KafkaUser with ACLs (4 services)
│   ├── topics/                       # Domain-driven topics (16 total)
│   │   ├── payments/                 # Payment domain (4 topics)
│   │   ├── ledger/                   # Ledger domain (4 topics)
│   │   ├── notifications/            # Notifications (4 topics)
│   │   └── audit/                    # Audit & compliance (4 topics)
│   └── schema-registry/              # Confluent Schema Registry
├── schemas/
│   └── avro/                         # Avro event schemas (4 schemas)
├── .github/workflows/                # ✅ Enterprise CI/CD automation (NEW!)
│   ├── build-packages.yml            # Docker build & push with security scanning
│   ├── release.yml                   # Automated releases with changelog
│   └── kafka-deploy.yml              # Infrastructure deployment with rollback
├── policies/opa/                     # ✅ Policy-as-Code (NEW!)
│   ├── kafka-topics.rego             # Topic governance (15 rules)
│   └── kafka-users.rego              # User/ACL governance (18 rules)
├── scripts/
│   └── rollback/                     # ✅ Automated rollback (NEW!)
│       ├── rollback-drill.sh         # Rollback testing automation
│       └── manual-rollback.sh        # Emergency rollback script
├── chaos/experiments/                # ✅ Chaos engineering (NEW!)
│   ├── deployment/                   # Deployment failure scenarios
│   └── 01-kill-leader-broker.yaml   # Broker failure testing
└── scripts/
    ├── install-strimzi.sh            # Operator installation
    ├── deploy-phase-a.sh             # Phase A deployment ✨ NEW
    └── complete-install.sh           # End-to-end automation
```


## 🚀 Quick Start

### Phase A Deployment (5 Minutes)

```bash
# 1. Deploy all Phase A components (topics + users + schemas)
./scripts/deploy-phase-a.sh

# 2. Verify deployment
kubectl get kafkatopic,kafkauser -n kafka

# 3. View topic details
kubectl get kafkatopic -n kafka -l domain=payments
kubectl get kafkatopic -n kafka -l domain=ledger
kubectl get kafkatopic -n kafka -l domain=notifications
kubectl get kafkatopic -n kafka -l domain=audit
```

### Manual Deployment

```bash
# 1. Install Strimzi operator
./scripts/install-strimzi.sh

# 2. Label Kubernetes nodes for Kafka
./scripts/label-kafka-nodes.sh node-1 node-2 node-3

# 3. Deploy Kafka cluster
kubectl apply -f platform/kafka/cluster.yaml

# 4. Deploy topics
kubectl apply -f platform/topics/payments/payments-topics.yaml
kubectl apply -f platform/topics/ledger/ledger-topics.yaml
kubectl apply -f platform/topics/notifications/notifications-topics.yaml
kubectl apply -f platform/topics/audit/audit-topics.yaml

# 5. Create KafkaUsers with ACLs
kubectl apply -f platform/kafka/users/
```

## 📋 Business Domains

### 1. Payments Domain

**Purpose**: Handle payment processing and lifecycle management

**Topics**:
- `payments.commands` - Payment initiation requests (12 partitions, 7d retention)
- `payments.events` - Payment state changes (12 partitions, 30d retention)
- `payments.validations` - Fraud/compliance checks (6 partitions, 14d retention)
- `payments.dead-letter` - Failed processing (3 partitions, 30d retention)

**ACLs**: Payments service has producer/consumer access + transactional ID

### 2. Ledger Domain

**Purpose**: Financial accounting with double-entry bookkeeping

**Topics**:
- `ledger.transactions` - All financial transactions (**infinite retention**)
- `ledger.balances` - Account balances (log compaction)
- `ledger.reconciliation` - Daily reconciliation (90d retention)
- `ledger.snapshots` - Account snapshots (365d retention)

**ACLs**: Ledger service + consumes from payments.events

### 3. Notifications Domain

**Purpose**: Multi-channel user notifications

**Topics**:
- `notifications.email` - Email queue (7d retention)
- `notifications.sms` - SMS queue (3d retention)
- `notifications.push` - Push notifications (3d retention)
- `notifications.audit` - Notification audit (90d retention)

**ACLs**: Notifications service + consumes from payments/ledger events

### 4. Audit Domain

**Purpose**: Compliance, regulatory reporting, security monitoring

**Topics**:
- `audit.events` - General audit trail (**7 years** retention)
- `audit.compliance` - Compliance events (**10 years** retention)
- `audit.security` - Security events (**7 years** retention)
- `audit.regulatory` - Regulatory reports (**10 years** retention)

**ACLs**: Audit service has **read access to ALL topics** for comprehensive monitoring

## 🔐 Security & Access Control

### Service ACLs Summary

| Service | Producer Topics | Consumer Topics | Quota (MB/s) |
|---------|----------------|-----------------|--------------|
| **Payments** | payments.*, audit.events | payments.* | 10/10 |
| **Ledger** | ledger.*, audit.events | ledger.*, payments.events | 20/20 |
| **Notifications** | notifications.*, audit.events | notifications.*, payments.*, ledger.* | 5/10 |
| **Audit** | audit.* | **ALL topics** (monitoring) | 20/30 |

### TLS Authentication

All services use **mutual TLS (mTLS)** with:
- Certificate-based authentication
- Unique service certificates
- Automatic rotation via Strimzi

### Extract Service Certificates

```bash
# Example: Extract payments service certificate
kubectl get secret payments-service -n kafka \
  -o jsonpath='{.data.user\.p12}' | base64 -d > payments-service.p12

kubectl get secret payments-service -n kafka \
  -o jsonpath='{.data.user\.password}' | base64 -d
```

## 📊 Event Schemas (Avro)

### Payment Command
```json
{
  "commandId": "uuid",
  "idempotencyKey": "string",
  "amount": {"value": "long", "currency": "string"},
  "sourceAccountId": "string",
  "destinationAccountId": "string",
  "paymentMethod": "CARD|BANK_TRANSFER|WALLET|..."
}
```

### Payment Event
```json
{
  "eventId": "uuid",
  "paymentId": "string",
  "eventType": "INITIATED|VALIDATED|AUTHORIZED|...",
  "status": "PENDING|SUCCESS|FAILED",
  "errorCode": "string"
}
```

### Ledger Transaction (Double-Entry)
```json
{
  "transactionId": "uuid",
  "entries": [
    {"accountId": "string", "entryType": "DEBIT|CREDIT", "amount": "long"}
  ]
}
```

### Audit Event
```json
{
  "eventId": "uuid",
  "actor": {"userId": "string", "ipAddress": "string"},
  "resource": {"resourceType": "string", "resourceId": "string"},
  "severityLevel": "INFO|WARNING|ERROR|CRITICAL"
}
```

## 📈 Configuration Highlights

| Feature | Configuration | Benefit |
|---------|--------------|---------|
| **High Availability** | 3 brokers, 3 zookeepers | Zero downtime deployments |
| **Data Durability** | min.insync.replicas=2/3 | Prevent data loss |
| **Performance** | JBOD storage, rack awareness | Disk parallelism |
| **Compliance** | 7-10 year retention | Regulatory requirements |
| **Integrity** | No compression on audit/ledger | Tamper-proof trails |
| **Exactly-Once Ready** | enable.idempotence=true | Phase B foundation |

## 📖 Event Flow Example

```
1. Client → POST /api/payments
   ↓
2. Payments Service → payments.commands
   ↓
3. Payments Service → payments.events (PAYMENT_INITIATED)
   ↓
4. Ledger Service → ledger.transactions (double-entry)
   ↓
5. Notifications Service → notifications.email
   ↓
6. Audit Service → audit.events (compliance trail)
```

For detailed implementation plan, see [Enterprise Maturity Roadmap](docs/ENTERPRISE_MATURITY_ROADMAP.md) and [Quick Start Guide](docs/ENTERPRISE_MATURITY_QUICK_START.md).

### Quick Start: Enterprise Requirements

```bash
# 1. Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-testing --create-namespace

# 2. Run first chaos experiment
kubectl apply -f chaos/experiments/01-kill-leader-broker.yaml

# 3. Deploy SLO monitoring
kubectl apply -f slo/prometheus-rules.yaml

# 4. Test incident runbook
cd runbooks && ./test-broker-outage.sh
```

**Quick Reference**: See `docs/ENTERPRISE_MATURITY_QUICK_START.md`

## 📚 Documentation

### Enterprise Maturity & Production Readiness
| Document | Description |
|----------|-------------|
| [Executive Summary](docs/EXECUTIVE_SUMMARY.md) | Business case with $3M+ ROI |
| [Enterprise Maturity Roadmap](docs/ENTERPRISE_MATURITY_ROADMAP.md) | 10 production requirements |
| [Enterprise Quick Start](docs/ENTERPRISE_MATURITY_QUICK_START.md) | Week-by-week implementation |
| [Chaos Engineering Guide](chaos/README.md) | Break it on purpose |
| [SLO Definitions](slo/README.md) | Service level objectives |
| [Broker Outage Runbook](runbooks/broker-outage.md) | Incident response playbook |

### Architecture & Setup
| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Platform architecture and components |
| [Getting Started](docs/GETTING_STARTED.md) | Comprehensive setup guide |
| [Node Configuration](docs/NODE_CONFIGURATION.md) | Node labeling and optimization |

## 🛠️ Technology Stack

- **Kafka**: 3.6.0 (Strimzi 0.38.0)
- **Schema Registry**: Confluent Platform 7.5.0
- **Monitoring**: Prometheus + Grafana
- **Serialization**: Apache Avro
- **Orchestration**: Kubernetes
- **IaC**: Terraform (Phase E)

## 👥 Contributing

See individual domain documentation:
- Payments: `platform/topics/payments/README.md` (coming soon)
- Ledger: `platform/topics/ledger/README.md` (coming soon)
- Notifications: `platform/topics/notifications/README.md` (coming soon)
- Audit: `platform/topics/audit/README.md` (coming soon)

## 📞 Support

- **Slack**: #kafka-platform
- **Documentation**: `docs/` directory
- **Issues**: GitHub Issues

---

## 🏆 Production Readiness Status

| Category | Status | Details |
|----------|--------|---------|
| **Phase A** | ✅ Complete | 16 topics, 4 services, full RBAC |
| **Phase B** | 🔄 Ready | Exactly-once design complete |
| **Chaos Engineering** | 🔄 Ready | 6 experiments defined |
| **SLOs** | 🔄 Ready | 6 SLIs with error budgets |
| **Runbooks** | � Ready | Broker outage tested |
| **Governance** | 📋 Pending | CoE charter needed |
| **Scale Testing** | 📋 Pending | 500k msg/sec target |
| **Compliance** | 📋 Pending | Audit logging needed |

**Overall Maturity**: Foundation Complete → Production Hardening in Progress

---


4. Deploy Kafka cluster configuration from `platform/kafka/`

5. Set up observability with Prometheus and Grafana

6. Configure security policies

## Prerequisites

- Kubernetes cluster with **at least 3 nodes** (4 CPU, 16GB RAM each)
- Nodes labeled with `node-role.kubernetes.io/kafka=true`
- Terraform >= 1.0
- kubectl
- Helm

## Key Features

✅ **Dedicated Node Scheduling** - Kafka runs on labeled nodes for optimal performance  
✅ **High Availability** - 3+ broker cluster with pod anti-affinity across nodes  
✅ **Auto-tuned Nodes** - DaemonSet applies OS-level optimizations to Kafka nodes  
✅ **Production Ready** - TLS, ACLs, monitoring, and alerting included  
✅ **Multi-Environment** - Dev, staging, and prod configurations  

## Documentation

### Quick Links

- 🏗️ [Architecture Documentation](docs/ARCHITECTURE.md) - Platform architecture and components
- � [Getting Started Guide](docs/GETTING_STARTED.md) - Comprehensive setup guide
- �️ [Node Configuration Guide](docs/NODE_CONFIGURATION.md) - Node labeling and optimization
- � [Executive Summary](docs/EXECUTIVE_SUMMARY.md) - Business case and roadmap

### Installation

The fastest way to deploy Phase A:

```bash
./scripts/deploy-phase-a.sh
```

For detailed setup instructions, see [Getting Started](docs/GETTING_STARTED.md).

## Documentation
