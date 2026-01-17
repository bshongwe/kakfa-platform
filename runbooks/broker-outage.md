# Incident Runbook: Broker Outage

## Symptom
- Broker pod unavailable
- Broker not responding to health checks
- Under-replicated partitions detected

## Impact
- Reduced throughput (1/3 capacity lost if 1 of 3 brokers down)
- Potential data loss if min.insync.replicas not met
- Leader election storms

## Severity
**CRITICAL** - Immediate response required

---

## Immediate Actions (0-5 minutes)

### 1. Verify Broker Status

```bash
# Check broker pods
kubectl get pods -n kafka -l strimzi.io/name=fintech-kafka-kafka

# Expected output: All pods Running
# If one shows CrashLoopBackOff or Error, proceed
```

### 2. Identify Failed Broker

```bash
# Get broker ID from pod name
# Example: fintech-kafka-kafka-1 → Broker ID: 1

BROKER_ID=<failed-broker-id>
POD_NAME="fintech-kafka-kafka-${BROKER_ID}"

echo "Failed Broker: ${POD_NAME}"
```

### 3. Check Broker Logs

```bash
# View last 100 lines
kubectl logs -n kafka ${POD_NAME} --tail=100

# Common failures:
# - OutOfMemoryError: JVM heap exhausted
# - java.io.IOException: No space left on device
# - Network timeout errors
# - Log corruption
```

### 4. Check Under-Replicated Partitions

```bash
# From any running broker
kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions

# If count > 0: Data at risk
# If count = 0: Safe to proceed with recovery
```

### 5. Check Disk Space

```bash
# SSH to node or use node-problem-detector
kubectl get nodes -o wide
# Identify node running failed broker

# Check disk on node
kubectl debug node/<node-name> -it --image=alpine
df -h

# If disk > 90% full: DISK FULL scenario
```

---

## Diagnosis (5-15 minutes)

### Root Cause Analysis

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| OOMKilled | JVM heap too small | Increase memory limit |
| No space left | Disk full | Increase storage, clean logs |
| CrashLoopBackOff | Bad configuration | Rollback config change |
| Network timeout | Node network issue | Restart node network |
| Log corruption | Disk corruption | Delete corrupted segments |

### Common Failure Scenarios

#### Scenario A: Disk Full

```bash
# Check disk usage on broker
kubectl exec -n kafka ${POD_NAME} -- df -h /var/lib/kafka

# If > 90% full:
# 1. Increase retention (short-term)
# 2. Add storage (long-term)
```

**Resolution**:
```bash
# Option 1: Reduce retention temporarily
kubectl exec -n kafka ${POD_NAME} -- \
  kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name payments.events \
  --alter --add-config retention.ms=86400000  # 1 day

# Option 2: Scale up PVC (if storage class supports)
kubectl patch pvc data-fintech-kafka-kafka-${BROKER_ID} \
  -n kafka -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

#### Scenario B: Out of Memory

```bash
# Check memory usage
kubectl top pod -n kafka ${POD_NAME}

# If OOMKilled in describe:
kubectl describe pod -n kafka ${POD_NAME} | grep -i oom
```

**Resolution**:
```yaml
# Edit Kafka cluster resource
kubectl edit kafka fintech-kafka -n kafka

# Increase memory:
spec:
  kafka:
    resources:
      requests:
        memory: 8Gi  # Increase from 4Gi
      limits:
        memory: 12Gi  # Increase from 8Gi
```

#### Scenario C: Log Corruption

```bash
# Check for corruption errors in logs
kubectl logs -n kafka ${POD_NAME} | grep -i corrupt

# If log corruption detected:
# WARNING: This deletes corrupted segments
```

**Resolution**:
```bash
# 1. Stop broker (automatically happens if crashed)

# 2. Access broker data directory
kubectl exec -n kafka ${POD_NAME} -- \
  kafka-log-dirs.sh --describe --bootstrap-server localhost:9092 \
  --broker-list ${BROKER_ID}

# 3. Manual recovery (DANGEROUS - data loss possible)
# Only if absolutely necessary and team lead approved
kubectl exec -n kafka ${POD_NAME} -- \
  kafka-run-class.sh kafka.tools.DumpLogSegments \
  --deep-iteration --print-data-log \
  --files /var/lib/kafka/data/payments.events-0/00000000000000000000.log
```

---

## Recovery Steps (15-30 minutes)

### Option 1: Restart Broker Pod

```bash
# Delete pod, Kubernetes will recreate
kubectl delete pod -n kafka ${POD_NAME}

# Wait for pod to come back
kubectl wait --for=condition=Ready pod/${POD_NAME} -n kafka --timeout=5m

# Verify broker rejoined cluster
kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### Option 2: Rollback Recent Changes

```bash
# If broker failed after config change
git log --oneline platform/kafka/cluster.yaml

# Identify last known good version
git checkout <commit-hash> platform/kafka/cluster.yaml

# Apply rollback
kubectl apply -f platform/kafka/cluster.yaml

# Strimzi will reconcile and restart broker
```

### Option 3: Scale and Replace

```bash
# If broker is permanently damaged
# 1. Add new broker (if using StatefulSet, just delete pod)
kubectl delete pod -n kafka ${POD_NAME}

# 2. Wait for new broker to sync
# Monitor replication lag:
watch kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions
```

---

## Verification (Post-Recovery)

### Checklist

- [ ] All 3 broker pods Running
- [ ] No under-replicated partitions
- [ ] Leader election completed
- [ ] Producer/consumer traffic resumed
- [ ] Monitoring dashboards green

### Verification Commands

```bash
# 1. Check all brokers healthy
kubectl get pods -n kafka -l strimzi.io/name=fintech-kafka-kafka

# Expected: 3/3 Running

# 2. Check ISR status
kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions

# Expected: No topics listed

# 3. Test produce/consume
kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic test.recovery << EOF
test message 1
test message 2
EOF

kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic test.recovery --from-beginning --max-messages 2

# Expected: Both messages consumed

# 4. Check Prometheus metrics
# - kafka_server_replicamanager_underreplicatedpartitions == 0
# - up{job="kafka"} == 3

# 5. Verify SLO compliance
# - Check error budget impact
# - Update incident log
```

---

## Post-Incident

### Incident Report Template

```markdown
## Incident: Broker Outage

**Date**: 2026-01-17  
**Duration**: <start-time> to <end-time>  
**Severity**: CRITICAL  
**Impact**: <percentage> of traffic affected  

### Timeline
- 03:12: Alert fired - broker-1 unavailable
- 03:15: On-call paged
- 03:18: Root cause identified (disk full)
- 03:25: Recovery initiated (increased retention)
- 03:35: Broker recovered
- 03:40: Verification complete

### Root Cause
<detailed explanation>

### Action Items
1. [ ] Increase disk capacity (Owner: @platform-team, Due: 2026-01-20)
2. [ ] Add disk usage alerts (Owner: @sre-team, Due: 2026-01-18)
3. [ ] Update runbook with lessons learned (Owner: @on-call, Due: 2026-01-17)

### Error Budget Impact
- SLO: Broker Availability 99.95%
- Downtime: 23 minutes
- Error budget consumed: 15%
- Remaining: 85%
```

### Prevention

1. **Monitoring**: Add predictive disk usage alerts
2. **Automation**: Auto-expand PVCs before full
3. **Capacity Planning**: Regular review of storage growth
4. **Testing**: Quarterly broker failure drills

---

## Escalation

| Time Elapsed | Action |
|--------------|--------|
| 0-15 min | On-call engineer handles |
| 15-30 min | Escalate to Platform Team Lead |
| 30-60 min | Escalate to Engineering Manager |
| > 60 min | Incident Commander + Executive notification |

### Contact Information

- **Platform On-Call**: Slack #kafka-oncall
- **Platform Team Lead**: @platform-lead
- **Engineering Manager**: @eng-manager
- **Incident Commander**: Use PagerDuty escalation

---

## Related Runbooks

Additional runbooks are in development:
- Data Corruption Recovery
- Consumer Lag Resolution
- Network Partition Response

---

**Runbook Owner**: Platform SRE Team  
**Last Tested**: TBD  
**Last Updated**: January 17, 2026  
**Version**: 1.0
