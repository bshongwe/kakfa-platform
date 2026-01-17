# Chaos Engineering for Kafka

## Overview

This directory contains chaos experiments to validate Kafka platform resilience.

> **"If you have never killed brokers in prod-like envs, you are not production-ready."**

## Installation

### Install Chaos Mesh

```bash
# Add Chaos Mesh Helm repository
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-testing \
  --create-namespace \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.create=true

# Verify installation
kubectl get pods -n chaos-testing
```

### Access Chaos Mesh Dashboard

```bash
kubectl port-forward -n chaos-testing svc/chaos-dashboard 2333:2333
# Open: http://localhost:2333
```

## Chaos Scenarios

### Implemented Experiments

### 1. Kill Leader Broker

**Expected**: Leader re-election < 10s, no data loss

```bash
kubectl apply -f experiments/01-kill-leader-broker.yaml
```

### 2. Kill Controller

**Expected**: No data loss, new controller elected

```bash
kubectl apply -f experiments/02-kill-controller.yaml
```

### 3. Network Partition

**Expected**: ISR stabilizes within 30s

```bash
kubectl apply -f experiments/03-network-partition.yaml
```

### Planned Experiments (In Development)

The following experiments are planned but not yet implemented:

- **Disk Full Simulation**: Test graceful degradation when broker disk fills
- **Producer Flood**: Validate quota enforcement under high load
- **Consumer Lag Spike**: Test alerting when consumers fall behind

## Chaos Testing Schedule

### Weekly Automated Chaos (Non-Production Hours)

```yaml
schedule:
  day: Saturday
  time: 02:00 AM UTC
  duration: 4 hours
  experiments:
    - kill-leader-broker (x3)
    - network-partition (x2)
    - pod-failure (random)
```

### Monthly Disaster Recovery Drill

```yaml
scenario: Complete broker cluster failure
goal: Full recovery in < 30 minutes
participants: Platform team, Dev leads, SRE
validation: Data integrity, consumer recovery
```

### Quarterly Multi-Region Failover

```yaml
scenario: Primary region failure
goal: Failover to DR region in < 5 minutes
participants: All engineering teams
validation: Zero data loss, RTO/RPO met
```

## Experiment Results Tracking

### Success Criteria

| Experiment | SLO | Last Result | Status |
|------------|-----|-------------|--------|
| Kill Leader | < 10s re-election | TBD | ⏳ Pending |
| Kill Controller | 0 data loss | TBD | ⏳ Pending |
| Network Partition | < 30s ISR recovery | TBD | ⏳ Pending |

## Safety Procedures

### Pre-Experiment Checklist

- [ ] Verify backup/restore procedures tested
- [ ] Alert stakeholders of chaos window
- [ ] Confirm monitoring is operational
- [ ] Verify rollback procedures ready
- [ ] Set up incident bridge (if needed)

### During Experiment

- [ ] Monitor metrics dashboards
- [ ] Track recovery time
- [ ] Document any anomalies
- [ ] Verify automated recovery works

### Post-Experiment

- [ ] Generate experiment report
- [ ] Update runbooks if gaps found
- [ ] Document lessons learned
- [ ] Update SLO/error budget

## Emergency Stop

```bash
# Stop all active experiments
kubectl delete podchaos --all -n kafka
kubectl delete networkchaos --all -n kafka
kubectl delete iochaos --all -n kafka
kubectl delete stresschaos --all -n kafka
```

## Metrics to Monitor During Chaos

```promql
# Leader election time
kafka_controller_stats_leader_election_rate_and_time_ms

# Under-replicated partitions
kafka_server_replicamanager_underreplicatedpartitions

# ISR shrinks/expands
kafka_server_replicamanager_isrshrinks_total
kafka_server_replicamanager_isrexpands_total

# Producer request latency
kafka_network_requestmetrics_requests_latency_ms{request="Produce"}

# Consumer lag
kafka_consumergroup_lag

# Broker availability
up{job="kafka"}
```

## Chaos Engineering Best Practices

1. **Start Small**: Begin with low-impact experiments
2. **Hypothesis-Driven**: Define expected outcome before running
3. **Automate Recovery**: Validate automation works
4. **Monitor Everything**: Ensure observability during chaos
5. **Learn & Iterate**: Update runbooks after each experiment
6. **Gradual Blast Radius**: Increase scope over time
7. **Business Hours**: Run critical experiments during staffed hours

## Resources

- [Chaos Mesh Documentation](https://chaos-mesh.org/docs/)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [Kafka Failure Scenarios](https://kafka.apache.org/documentation/#replication)

---

**Owner**: Platform SRE Team  
**Status**: Experimental Framework Ready  
**Last Chaos Test**: TBD  
**Next Scheduled Chaos**: Saturday, 02:00 AM UTC
