# Rollback Drills & Procedures

## Overview

This directory contains automated and manual rollback scripts to ensure the platform can quickly recover from failed deployments.

> **"At 03:12 AM, you don't want to be reading documentation. You want a script that just works."**

## Scripts

### 1. Automated Rollback Drill (`rollback-drill.sh`)

Fully automated drill that simulates a deployment failure and validates rollback procedures.

**Usage**:
```bash
./rollback-drill.sh staging
```

**What it does**:
1. ✅ Creates baseline snapshot of current state
2. 💥 Injects bad configuration (simulated failure)
3. 🔍 Detects the failure
4. 🔄 Executes rollback procedure
5. ✅ Verifies system health post-rollback
6. 📊 Generates detailed report

**Example Output**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  KAFKA ROLLBACK DRILL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Preflight checks passed
📸 Creating baseline snapshot...
✓ Saved 16 topics
✓ Saved 4 users
✓ Saved status of 3 brokers

💥 Injecting bad configuration...
⚠️  Bad configuration applied

🔍 Detecting deployment failure...
❌ Replication factor is 1 (should be 3) - FAILURE DETECTED
✅ Failure detection working correctly

🔄 Executing rollback procedure...
✓ Deleted bad topic
✓ Topics restored
✓ Users restored
✅ Rollback completed in 47 seconds

✅ Verifying system health post-rollback...
✅ All 3/3 brokers are running
✅ Topic count matches baseline (16 topics)
✅ User count matches baseline (4 users)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Rollback drill completed successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Manual Rollback (`manual-rollback.sh`)

Use for emergency manual rollback during an actual incident.

**Usage**:
```bash
# List available snapshots
ls -lh /tmp/rollback-*.tar.gz

# Restore from snapshot
./manual-rollback.sh /tmp/rollback-snapshot-abc123.tar.gz
```

**Safety Features**:
- ✅ Interactive confirmation before rollback
- ✅ Separate cluster config restore (optional)
- ✅ Validates snapshot structure
- ✅ Provides verification commands

## Rollback SLA

| Metric | Target | Measured |
|--------|--------|----------|
| **Detection Time** | < 60s | Automated monitoring |
| **Rollback Time** | < 300s (5 min) | Validated by drill |
| **Data Loss** | 0 topics/users | Validated by drill |
| **Broker Availability** | 100% uptime | No broker restarts |

## Drill Schedule

### Weekly Drills (Non-Production)
```bash
# Every Saturday 2 AM UTC
0 2 * * 6 /path/to/rollback-drill.sh staging >> /var/log/kafka-drills.log 2>&1
```

### Monthly Drills (Production-Like)
- **First Saturday of month**: Production environment drill (scheduled downtime)
- **Participants**: Full engineering team
- **Duration**: 2 hours (includes post-mortem)

### Quarterly Drills (Executive Tabletop)
- **Scenario**: Multi-region failure + rollback
- **Participants**: Engineering + Management + On-call
- **Objective**: Validate escalation procedures

## Chaos Engineering Integration

The rollback drills are complemented by chaos experiments in `chaos/experiments/deployment/`:

### Failed Deployment Chaos Workflow

```bash
# Run deployment failure simulation
kubectl apply -f ../../chaos/experiments/deployment/failed-deployment.yaml

# Watch progress
kubectl get workflow failed-deployment-simulation -n chaos-testing -w
```

**Scenarios Tested**:
1. Bad topic configuration (over-partitioning)
2. Incompatible schema change
3. Invalid ACL configuration

## Snapshot Management

### Automatic Snapshots (Production)

GitHub Actions creates snapshots before every deployment:

```yaml
# In .github/workflows/kafka-deploy.yml
- name: Create rollback snapshot
  run: |
    kubectl get kafkatopic -n kafka -o yaml > /tmp/snapshot/topics.yaml
    kubectl get kafkauser -n kafka -o yaml > /tmp/snapshot/users.yaml
    tar -czf rollback-snapshot-${{ github.sha }}.tar.gz /tmp/snapshot/
```

### Manual Snapshots

```bash
# Create manual snapshot
SNAPSHOT_ID="manual-$(date +%Y%m%d-%H%M%S)"
mkdir -p /tmp/snapshot-${SNAPSHOT_ID}

kubectl get kafkatopic -n kafka -o yaml > /tmp/snapshot-${SNAPSHOT_ID}/topics.yaml
kubectl get kafkauser -n kafka -o yaml > /tmp/snapshot-${SNAPSHOT_ID}/users.yaml
kubectl get kafka -n kafka -o yaml > /tmp/snapshot-${SNAPSHOT_ID}/cluster.yaml

tar -czf /tmp/rollback-snapshot-${SNAPSHOT_ID}.tar.gz -C /tmp snapshot-${SNAPSHOT_ID}

echo "✅ Snapshot created: /tmp/rollback-snapshot-${SNAPSHOT_ID}.tar.gz"
```

### Snapshot Retention

| Environment | Retention | Storage |
|-------------|-----------|---------|
| **Production** | 90 days | S3 bucket |
| **Staging** | 30 days | Local/S3 |
| **Dev** | 7 days | Local only |

## Rollback Runbook

### Step 1: Detect Failure

**Automated Detection** (preferred):
- GitHub Actions health checks fail
- Prometheus alerts fire (`KafkaDeploymentFailed`)
- ArgoCD sync status shows degraded

**Manual Detection**:
```bash
# Check topic status
kubectl get kafkatopic -n kafka

# Check broker health
kubectl get pods -n kafka -l strimzi.io/name=fintech-kafka-kafka

# Check under-replicated partitions
kubectl exec -n kafka fintech-kafka-kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions
```

### Step 2: Assess Impact

```bash
# Check error budget status
curl http://prometheus:9090/api/v1/query?query=kafka_error_budget_remaining

# Check active alerts
kubectl get prometheusrule -n kafka -o yaml | grep -i alert
```

### Step 3: Execute Rollback

**Option A: Automated (GitHub Actions)**
```bash
# Trigger rollback workflow
gh workflow run kafka-rollback.yml -f snapshot_id=<sha>
```

**Option B: Manual (Emergency)**
```bash
./manual-rollback.sh /tmp/rollback-snapshot-<sha>.tar.gz
```

### Step 4: Verify Recovery

```bash
# Check all resources
kubectl get kafkatopic,kafkauser,kafka -n kafka

# Test producer
kubectl run test-producer --rm -i --restart=Never --image=confluentinc/cp-kafka:7.5.0 -n kafka -- \
  kafka-console-producer --bootstrap-server fintech-kafka-kafka-bootstrap:9092 --topic test-topic <<EOF
{"test": "message"}
EOF

# Test consumer
kubectl run test-consumer --rm -i --restart=Never --image=confluentinc/cp-kafka:7.5.0 -n kafka -- \
  kafka-console-consumer --bootstrap-server fintech-kafka-kafka-bootstrap:9092 \
  --topic test-topic --from-beginning --max-messages 1 --timeout-ms 10000
```

### Step 5: Post-Incident

1. **Generate incident report**: `./rollback-drill.sh` auto-generates template
2. **Update runbooks**: Document any gaps found
3. **Review error budget**: Deduct from monthly budget
4. **Schedule post-mortem**: Within 48 hours

## Metrics & Reporting

### Drill Metrics Tracked

Every drill execution generates a report with:

```markdown
## Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Rollback Time** | 47s | < 300s | ✅ PASS |
| **Data Loss** | 0 topics | 0 topics | ✅ PASS |
| **Brokers Online** | 3/3 | 3/3 | ✅ PASS |
| **Topics Restored** | Yes | Yes | ✅ PASS |
| **Users Restored** | Yes | Yes | ✅ PASS |
```

### Historical Trends

Track rollback time over time:

```bash
# Extract rollback times from reports
grep "Rollback Time" /tmp/rollback-drill-report-*.md | \
  awk '{print $5}' | \
  sort -n
```

## Common Failure Scenarios

### Scenario 1: Over-Partitioned Topic

**Symptom**: Topic created with > 50 partitions  
**Detection**: OPA policy violation  
**Rollback**: Delete topic, restore from baseline  
**Prevention**: Enforce OPA policies in CI/CD  

### Scenario 2: Broken ACLs

**Symptom**: Service cannot produce/consume  
**Detection**: Authentication errors in logs  
**Rollback**: Restore KafkaUser from snapshot  
**Prevention**: ACL validation in pre-deployment  

### Scenario 3: Schema Incompatibility

**Symptom**: Consumers fail to deserialize  
**Detection**: Schema registry errors  
**Rollback**: Delete incompatible schema version  
**Prevention**: Schema compatibility checks  

### Scenario 4: Cluster Configuration Change

**Symptom**: Broker restarts unexpectedly  
**Detection**: Broker pod restarts  
**Rollback**: Restore Kafka cluster config  
**Prevention**: Cluster changes require manual approval  

## Integration with Error Budget

Rollback events are tracked against SLO error budget:

```yaml
# slo/README.md
error_budget_policy:
  rollback_event:
    cost: 10%  # Each rollback costs 10% of monthly error budget
    threshold: 3  # Max 3 rollbacks per month before freeze
```

If error budget depleted:
- ❌ All non-critical deployments frozen
- ✅ Rollbacks still allowed (safety first)
- ⚠️ Requires VP Engineering approval to proceed

## Best Practices

1. **✅ DO**: Run drills during business hours (team available)
2. **✅ DO**: Test rollback procedures monthly minimum
3. **✅ DO**: Create snapshots before every deployment
4. **✅ DO**: Validate rollback success (don't assume it worked)
5. **❌ DON'T**: Skip validation steps to save time
6. **❌ DON'T**: Test only happy path (inject real failures)
7. **❌ DON'T**: Rely on manual procedures only (automate!)

## Training & Onboarding

### New Team Members

Required certification:
1. Read this documentation
2. Run `rollback-drill.sh` in dev environment
3. Shadow production drill
4. Lead drill in staging environment
5. Complete incident response quiz

### Refresher Training

Every 6 months, all engineers must:
- Complete rollback drill
- Review updated runbooks
- Participate in tabletop exercise

## Support & Escalation

| Severity | Contact | Response Time |
|----------|---------|---------------|
| **SEV-1** | On-call + Incident Commander | 5 minutes |
| **SEV-2** | Platform team lead | 15 minutes |
| **SEV-3** | Platform team Slack | 1 hour |

**Slack Channels**:
- `#kafka-incidents` - Active incidents
- `#kafka-platform` - General support
- `#kafka-oncall` - Escalation path

---

**Document Owner**: Platform SRE Team  
**Last Updated**: January 17, 2026  
**Next Drill**: _Schedule here_  
**Last Successful Drill**: _Record here_
