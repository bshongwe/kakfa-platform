# SLO/SLI Definitions for Kafka Platform

## Service Level Indicators (SLIs)

### 1. Produce Success Rate

**Definition**: Percentage of successful produce requests

```promql
# Recording rule
- record: kafka:produce_success_rate:5m
  expr: |
    sum(rate(kafka_producer_record_send_total{result="success"}[5m]))
    /
    sum(rate(kafka_producer_record_send_total[5m]))
```

**Target**: 99.99%  
**Error Budget**: 0.01% (52 minutes/year of failed produces)

### 2. Consume Latency (p99)

**Definition**: 99th percentile latency from produce to consume

```promql
# Recording rule
- record: kafka:consume_latency_p99:5m
  expr: |
    histogram_quantile(0.99,
      rate(kafka_consumer_fetch_latency_avg_bucket[5m])
    )
```

**Target**: < 500ms  
**Error Budget**: 1% of requests may exceed 500ms

### 3. Data Durability

**Definition**: Messages lost / Messages sent

```promql
# Recording rule (requires producer idempotence tracking)
- record: kafka:data_loss_rate:5m
  expr: |
    (
      sum(rate(kafka_producer_record_send_total[5m]))
      -
      sum(rate(kafka_topic_partition_current_offset[5m]))
    )
    /
    sum(rate(kafka_producer_record_send_total[5m]))
```

**Target**: 100% (zero data loss)  
**Error Budget**: 0 messages lost

### 4. Schema Violations

**Definition**: Invalid schema registrations / Total registrations

```promql
# Recording rule
- record: kafka:schema_violations:5m
  expr: |
    sum(rate(schema_registry_errors_total{error_type="incompatible"}[5m]))
    /
    sum(rate(schema_registry_requests_total[5m]))
```

**Target**: 0%  
**Error Budget**: 0 violations

### 5. Broker Availability

**Definition**: Broker uptime / Total time

```promql
# Recording rule
- record: kafka:broker_availability:5m
  expr: |
    avg(up{job="kafka"})
```

**Target**: 99.95%  
**Error Budget**: 4.38 hours/year downtime

### 6. Replication Lag

**Definition**: Maximum lag across all in-sync replicas

```promql
# Recording rule
- record: kafka:max_replication_lag:5m
  expr: |
    max(kafka_server_replicamanager_isrshrinks_total)
```

**Target**: < 1000 messages  
**Error Budget**: 5% of time may exceed 1000 messages

---

## Service Level Objectives (SLOs)

### Summary Table

| SLI | Measurement Window | Target | Error Budget | Current |
|-----|-------------------|--------|--------------|---------|
| Produce Success Rate | 30 days | 99.99% | 0.01% | TBD |
| Consume Latency p99 | 30 days | < 500ms | 1% | TBD |
| Data Durability | 30 days | 100% | 0 msgs | TBD |
| Schema Violations | 30 days | 0% | 0 | TBD |
| Broker Availability | 30 days | 99.95% | 4.38h | TBD |
| Replication Lag | 30 days | < 1000 msgs | 5% | TBD |

---

## Error Budget Policy

### Escalation Ladder

```yaml
error_budget_remaining:
  100% - 80%:
    status: HEALTHY
    action: Normal operations
    release_velocity: Full speed
    
  80% - 50%:
    status: CAUTION
    action: Monitor closely
    release_velocity: Normal
    restrictions: None
    
  50% - 20%:
    status: WARNING
    action: |
      - Increase monitoring
      - Review recent changes
      - Prepare incident response
    release_velocity: Reduced
    restrictions: |
      - Feature freezes for high-risk changes
      - Require SRE approval for deployments
    
  20% - 10%:
    status: CRITICAL
    action: |
      - HALT non-critical releases
      - Focus on reliability improvements
      - Daily error budget reviews
    release_velocity: Minimal
    restrictions: |
      - Only critical bug fixes
      - SRE team approval required
      - Post-deployment validation mandatory
    
  < 10%:
    status: INCIDENT
    action: |
      - LOCKDOWN: Critical fixes only
      - All hands on reliability
      - Executive notification
    release_velocity: ZERO
    restrictions: |
      - No new features
      - Emergency fixes only
      - VP Engineering approval required
      
  < 5%:
    status: EMERGENCY
    action: |
      - Complete deployment freeze
      - War room activated
      - Customer communication
    release_velocity: FROZEN
    restrictions: ALL
```

### Recovery Actions by SLI

#### When Produce Success Rate < 99.99%

1. Check broker health
2. Review producer configurations
3. Inspect network issues
4. Validate quota enforcement
5. Emergency: Increase retries, reduce batch sizes

#### When Consume Latency p99 > 500ms

1. Check consumer lag
2. Review partition assignment
3. Inspect network latency
4. Validate consumer configurations
5. Emergency: Scale consumers, reduce fetch sizes

#### When Data Loss Detected

1. **IMMEDIATE STOP**: Halt all producers
2. Investigate ISR status
3. Check broker logs for corruption
4. Validate replication settings
5. Recovery: Replay from backup, fix configuration

#### When Schema Violations > 0

1. Identify incompatible schema
2. Rollback to previous version
3. Block producer with bad schema
4. Notify schema owners
5. Emergency: Enforce schema validation

---

## Monitoring & Alerting

### Alert Rules

```yaml
# Produce success rate below SLO
- alert: ProduceSuccessRateLow
  expr: kafka:produce_success_rate:5m < 0.9999
  for: 5m
  labels:
    severity: critical
    slo: produce_success_rate
  annotations:
    summary: "Produce success rate below SLO"
    description: "Current: {{ $value | humanizePercentage }}, Target: 99.99%"
    error_budget_impact: "{{ $value | humanize }} error budget consumed"

# Consume latency above SLO
- alert: ConsumeLatencyHigh
  expr: kafka:consume_latency_p99:5m > 500
  for: 5m
  labels:
    severity: warning
    slo: consume_latency
  annotations:
    summary: "Consume latency p99 above SLO"
    description: "Current: {{ $value }}ms, Target: < 500ms"

# Data loss detected
- alert: DataLossDetected
  expr: kafka:data_loss_rate:5m > 0
  for: 1m
  labels:
    severity: critical
    slo: data_durability
  annotations:
    summary: "DATA LOSS DETECTED"
    description: "Messages lost: {{ $value }}"
    runbook: "runbooks/data-corruption.md"

# Schema violations
- alert: SchemaViolations
  expr: kafka:schema_violations:5m > 0
  for: 1m
  labels:
    severity: critical
    slo: schema_violations
  annotations:
    summary: "Schema violations detected"
    description: "Incompatible schemas: {{ $value }}"
    runbook: "runbooks/schema-rollback.md"

# Broker unavailable
- alert: BrokerDown
  expr: kafka:broker_availability:5m < 0.9995
  for: 2m
  labels:
    severity: critical
    slo: broker_availability
  annotations:
    summary: "Broker availability below SLO"
    description: "Current: {{ $value | humanizePercentage }}, Target: 99.95%"
    runbook: "runbooks/broker-outage.md"

# Replication lag high
- alert: ReplicationLagHigh
  expr: kafka:max_replication_lag:5m > 1000
  for: 10m
  labels:
    severity: warning
    slo: replication_lag
  annotations:
    summary: "Replication lag above threshold"
    description: "Max lag: {{ $value }} messages, Target: < 1000"
```

---

## Error Budget Calculation

### Formula

```
Error Budget = (1 - SLO) × Total Valid Events
```

### Example: Produce Success Rate

```
SLO: 99.99%
Error Budget: 0.01%
Monthly Events: 1,000,000,000 produces

Error Budget = 0.0001 × 1,000,000,000 = 100,000 failed produces/month

If we've had 50,000 failures this month:
Error Budget Remaining = (100,000 - 50,000) / 100,000 = 50%
Status: WARNING ⚠️
```

### Burn Rate

**Fast Burn** (1x error budget in 1 day):
```promql
# Alert if error budget will be exhausted in < 2 days
- alert: ErrorBudgetFastBurn
  expr: |
    (1 - kafka:produce_success_rate:1h) * 24 * 30
    >
    (1 - 0.9999)
  for: 1h
```

**Slow Burn** (1x error budget in 30 days):
```promql
# Alert if error budget tracking for exhaustion in 30 days
- alert: ErrorBudgetSlowBurn
  expr: |
    (1 - kafka:produce_success_rate:6h) * 30
    >
    (1 - 0.9999) * 0.5  # 50% of budget
  for: 6h
```

---

## SLO Review Process

### Weekly SLO Review

- Review error budget consumption
- Identify top contributors to SLO violations
- Prioritize reliability improvements

### Monthly SLO Report

- Generate SLO compliance report
- Update error budget policy if needed
- Present to engineering leadership

### Quarterly SLO Revision

- Review SLO targets (are they realistic?)
- Update based on business requirements
- Adjust error budgets

---

## Dashboard Links

- **SLO Overview**: `grafana/dashboards/slo-overview.json`
- **Error Budget**: `grafana/dashboards/error-budget.json`
- **SLI Details**: `grafana/dashboards/sli-details.json`

---

**Owner**: Platform SRE Team  
**Last Updated**: January 17, 2026  
**Next Review**: Weekly on Mondays  
**Status**: Active Monitoring
