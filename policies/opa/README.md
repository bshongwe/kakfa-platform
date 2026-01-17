# Open Policy Agent (OPA) Policies for Kafka

## Overview

This directory contains OPA policies that enforce governance, security, and best practices for Kafka platform resources.

**OPA Version**: Compatible with OPA v0.42.0+ (uses Rego v1 syntax with `if` keyword)

> **Note**: These policies use modern Rego syntax introduced in OPA v0.42.0. The `if` keyword is required before rule bodies and the `contains` keyword for partial set rules.

## Policies

### 1. Topic Governance (`kafka-topics.rego`)

**Enforces**:
- ✅ Naming conventions (`domain.entity` pattern)
- ✅ Partition limits (max 50, min 3 for production)
- ✅ Replication factor (min 3 for production)
- ✅ Retention policies (7 years for audit, infinite for ledger)
- ✅ Compression restrictions (no compression for compliance topics)
- ✅ Domain restrictions (only approved domains)
- ✅ Required labels (domain, owner, environment)

**Examples**:
```yaml
# ❌ FAIL: Invalid naming
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: MyTopic  # Uppercase not allowed
  
# ✅ PASS: Valid topic
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: payments.commands
  labels:
    domain: payments
    owner: platform
    environment: production
spec:
  partitions: 12
  replicas: 3
  config:
    min.insync.replicas: "2"
    retention.ms: "2592000000"  # 30 days
```

### 2. User & ACL Governance (`kafka-users.rego`)

**Enforces**:
- ✅ TLS authentication required
- ✅ No wildcard topic permissions (except audit-service)
- ✅ Resource quotas for production users
- ✅ Consumer group must match service name
- ✅ Domain segregation (users can only access their domain)
- ✅ Required labels and annotations

**Examples**:
```yaml
# ❌ FAIL: Wildcard access
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-service
spec:
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: "*"  # Not allowed!
          
# ✅ PASS: Valid user
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: payments-service
  labels:
    team: payments
    service: payments
    environment: production
    domain: payments
  annotations:
    kafka.io/owner-email: platform@example.com
    kafka.io/oncall-team: platform-team
    kafka.io/write-justification: "Payment processing requires write access"
spec:
  authentication:
    type: tls
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: payments.commands
          patternType: literal
        operations:
          - Read
          - Write
      - resource:
          type: group
          name: payments-service-consumer
          patternType: literal
        operations:
          - Read
  quotas:
    producerByteRate: 10485760  # 10 MB/s
    consumerByteRate: 10485760  # 10 MB/s
    requestPercentage: 50
```

## Installation

### 1. Install OPA CLI

```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/
```

### 2. Validate Policies

```bash
# Test policy syntax
opa test policies/opa -v

# Evaluate a specific manifest
opa eval --data policies/opa/kafka-topics.rego \
         --input platform/topics/payments/payments-topics.yaml \
         'data.kafka.topics.deny'
```

### 3. Integrate with CI/CD

The policies are automatically enforced in GitHub Actions workflow (`.github/workflows/kafka-deploy.yml`).

## Testing

### Run All Tests

```bash
# From repository root
opa test policies/opa tests/opa -v
```

### Test Individual Policy

```bash
# Test topic policy
opa test policies/opa/kafka-topics.rego tests/opa/kafka-topics_test.rego -v

# Test user policy
opa test policies/opa/kafka-users.rego tests/opa/kafka-users_test.rego -v
```

### Manual Validation

```bash
# Test against actual manifests
for file in platform/topics/**/*.yaml; do
  echo "Testing $file..."
  opa eval --fail-defined \
    --data policies/opa/kafka-topics.rego \
    --input $file \
    'data.kafka.topics.deny'
done
```

## Policy Rules Summary

### Topic Policy Rules

| Rule | Severity | Description |
|------|----------|-------------|
| Naming convention | ERROR | Must match `domain.entity` pattern |
| Partition limit | ERROR | Max 50 partitions (prevent over-partitioning) |
| Partition minimum | ERROR | Min 3 partitions for production |
| Replication factor | ERROR | Min 3 replicas for production |
| min.insync.replicas | ERROR | Min 2 for production |
| Audit retention | ERROR | Min 7 years for audit topics |
| Ledger retention | ERROR | Infinite for ledger topics |
| Compression | ERROR | No compression for audit/ledger |
| Domain whitelist | ERROR | Only approved domains allowed |
| Required labels | ERROR | domain, owner, environment |
| Partition power-of-2 | WARN | Optimal key distribution |
| Retention cost | WARN | >90 days triggers warning |

### User Policy Rules

| Rule | Severity | Description |
|------|----------|-------------|
| TLS authentication | ERROR | TLS required for all users |
| Wildcard topics | ERROR | No `*` topic access (except audit) |
| Delete operation | ERROR | Delete not allowed |
| Alter operation | ERROR | Alter requires admin label |
| Production quotas | ERROR | Quotas required for production |
| Producer quota limit | ERROR | Max 50 MB/s |
| Consumer quota limit | ERROR | Max 100 MB/s |
| Consumer group naming | ERROR | Must match service name |
| Domain segregation | ERROR | Users can only access own domain |
| Required labels | ERROR | team, service, environment |
| Production annotations | ERROR | owner-email, oncall-team required |
| Write justification | ERROR | Write permissions need annotation |
| Request quota | WARN | Should set requestPercentage |

## Enforcement Workflow

```
┌──────────────────────────────────────────┐
│  Developer commits Kafka manifest       │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  GitHub Actions: Validate stage          │
│  ├─ kubectl apply --dry-run=client       │
│  └─ OPA policy evaluation                │
└──────────────┬───────────────────────────┘
               │
               ▼
        ┌──────┴──────┐
        │             │
    [PASS]         [FAIL]
        │             │
        ▼             ▼
   Continue      Block PR
   Pipeline      + Comment
```

## Exemptions

Some policies allow exemptions via labels/annotations:

### Admin Users
```yaml
metadata:
  labels:
    admin: "true"  # Allows Alter operations
```

### Cross-Domain Access
Certain services can access multiple domains:
- `ledger-service` can read `payments.*`
- `notifications-service` can read `payments.*` and `ledger.*`
- `audit-service` can read all topics

### Transaction Approval
```yaml
metadata:
  labels:
    kafka.io/transactions-approved: "true"  # Allows transactionalId
```

## Adding New Policies

1. Create `.rego` file in `policies/opa/`
2. Add corresponding tests in `tests/opa/`
3. Update this README
4. Update GitHub Actions workflow if needed

### Example Policy Structure

```rego
package kafka.my_policy

# Deny rule (hard failure)
deny[msg] {
    input.kind == "KafkaTopic"
    # ... condition ...
    msg := sprintf("Error message: %s", [input.metadata.name])
}

# Warning rule (soft failure)
warn[msg] {
    input.kind == "KafkaTopic"
    # ... condition ...
    msg := sprintf("Warning message: %s", [input.metadata.name])
}
```

## Common Violations

### Topic Violations

```bash
# Over-partitioned topic
❌ Topic 'payments.events' has 100 partitions (max: 50)

# Missing min.insync.replicas
❌ Topic 'payments.commands' must have min.insync.replicas >= 2

# Wrong retention for audit
❌ Audit topic 'audit.events' must have >= 7 years retention
```

### User Violations

```bash
# Wildcard access
❌ User 'my-service' must not have wildcard (*) topic access

# Missing quotas
❌ Production user 'payments-service' must have resource quotas defined

# Domain violation
❌ User 'payments-service' (domain: payments) cannot access topic 'ledger.transactions' (domain: ledger)
```

## Monitoring & Alerts

Policy violations are tracked in:
- GitHub Actions logs
- Pre-commit hooks (optional)
- ArgoCD sync status (if using GitOps)

## References

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [OPA Rego Language](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Kafka Topic Best Practices](https://kafka.apache.org/documentation/#topicconfigs)
- [Strimzi CRD Reference](https://strimzi.io/docs/operators/latest/configuring.html)

---

**Policy Owner**: Platform Team  
**Last Updated**: January 17, 2026  
**Version**: 1.0
