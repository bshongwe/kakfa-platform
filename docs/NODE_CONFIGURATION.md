# Node Configuration for Kafka Platform

This document describes how to configure Kubernetes nodes for dedicated Kafka workloads.

## Overview

The Kafka platform uses node affinity rules to ensure Kafka components (brokers, Zookeeper, Schema Registry) run on dedicated nodes. This provides:

- **Resource Isolation**: Kafka workloads don't compete with other applications
- **Performance Optimization**: Nodes can be tuned specifically for Kafka (SSD, high memory, network)
- **Cost Optimization**: Different node types for different workload priorities
- **High Availability**: Pod anti-affinity ensures brokers are spread across nodes

## Node Labeling

### Label Kafka Nodes

To designate nodes for Kafka workloads, label them with `node-role.kubernetes.io/kafka=true`:

```bash
# Label a single node
kubectl label node <node-name> node-role.kubernetes.io/kafka=true

# Label multiple nodes
kubectl label nodes <node-1> <node-2> <node-3> node-role.kubernetes.io/kafka=true
```

### Verify Node Labels

```bash
# List all nodes with Kafka label
kubectl get nodes -l node-role.kubernetes.io/kafka=true

# Show all labels on a node
kubectl get node <node-name> --show-labels
```

### Remove Kafka Label (if needed)

```bash
kubectl label node <node-name> node-role.kubernetes.io/kafka-
```

## Node Requirements

### Minimum Requirements

For a production Kafka deployment, you need at least **3 nodes** with:

- **CPU**: 4+ cores per node
- **Memory**: 16GB+ RAM per node
- **Storage**: 
  - 100GB+ for Kafka broker data (preferably SSD)
  - 10GB+ for Zookeeper data
- **Network**: 10 Gbps+ network bandwidth

### Recommended Node Types (by Cloud Provider)

#### AWS
```bash
# EC2 instance types
- m5.xlarge (4 vCPU, 16 GB RAM) - General purpose
- r5.xlarge (4 vCPU, 32 GB RAM) - Memory optimized
- i3.2xlarge (8 vCPU, 61 GB RAM, NVMe SSD) - Storage optimized
```

#### GCP
```bash
# GCE machine types
- n2-standard-4 (4 vCPU, 16 GB RAM)
- n2-highmem-4 (4 vCPU, 32 GB RAM)
- n2-custom with local SSD
```

#### Azure
```bash
# Azure VM sizes
- Standard_D4s_v3 (4 vCPU, 16 GB RAM)
- Standard_E4s_v3 (4 vCPU, 32 GB RAM)
- Standard_L8s_v2 (8 vCPU, 64 GB RAM, NVMe)
```

## Node Affinity Configuration

### Kafka Brokers

Kafka brokers use **requiredDuringSchedulingIgnoredDuringExecution** affinity:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role.kubernetes.io/kafka
              operator: In
              values:
                - "true"
```

This means:
- ✅ Kafka pods **MUST** be scheduled on nodes with the `node-role.kubernetes.io/kafka=true` label
- ❌ If no such nodes exist, pods will remain in `Pending` state

### Schema Registry

Schema Registry uses **preferredDuringSchedulingIgnoredDuringExecution** affinity:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: node-role.kubernetes.io/kafka
              operator: In
              values:
                - "true"
```

This means:
- ✅ Schema Registry **prefers** Kafka-labeled nodes
- ✅ But can run on other nodes if necessary (more flexible)

## Pod Anti-Affinity

Both Kafka and Zookeeper use pod anti-affinity to spread replicas across different nodes:

```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - kafka
        topologyKey: kubernetes.io/hostname
```

This ensures:
- Multiple Kafka brokers don't run on the same node
- Better fault tolerance and resource distribution

## Taints and Tolerations (Optional)

For even stricter isolation, you can taint Kafka nodes to prevent non-Kafka pods from scheduling:

### Add Taint to Kafka Nodes

```bash
kubectl taint nodes <node-name> workload=kafka:NoSchedule
```

### Add Tolerations to Kafka Configuration

If you taint nodes, update `platform/kafka/cluster.yaml`:

```yaml
spec:
  kafka:
    template:
      pod:
        tolerations:
          - key: "workload"
            operator: "Equal"
            value: "kafka"
            effect: "NoSchedule"
```

## Node Optimization

### OS-Level Tuning

Apply these settings on Kafka nodes for optimal performance:

```bash
# Increase file descriptors
echo "* soft nofile 100000" >> /etc/security/limits.conf
echo "* hard nofile 100000" >> /etc/security/limits.conf

# Increase max map count
sysctl -w vm.max_map_count=262144

# Disable swap
swapoff -a

# Network tuning
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728
sysctl -w net.ipv4.tcp_rmem='4096 87380 134217728'
sysctl -w net.ipv4.tcp_wmem='4096 65536 134217728'
```

### Kubernetes DaemonSet for Tuning

Create a DaemonSet to automatically apply these settings:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kafka-node-tuning
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: kafka-node-tuning
  template:
    metadata:
      labels:
        name: kafka-node-tuning
    spec:
      nodeSelector:
        node-role.kubernetes.io/kafka: "true"
      hostPID: true
      hostNetwork: true
      containers:
      - name: tuning
        image: alpine:3.18
        command:
          - sh
          - -c
          - |
            sysctl -w vm.max_map_count=262144
            sysctl -w net.core.rmem_max=134217728
            sysctl -w net.core.wmem_max=134217728
            tail -f /dev/null
        securityContext:
          privileged: true
```

## Deployment Process

### Step 1: Prepare Nodes

```bash
# Identify nodes for Kafka
kubectl get nodes

# Label the nodes
kubectl label nodes node-1 node-2 node-3 node-role.kubernetes.io/kafka=true

# Verify labels
kubectl get nodes -l node-role.kubernetes.io/kafka=true -o wide
```

### Step 2: (Optional) Taint Nodes

```bash
kubectl taint nodes node-1 node-2 node-3 workload=kafka:NoSchedule
```

### Step 3: Deploy Kafka

```bash
# Deploy the Kafka cluster
kubectl apply -f platform/kafka/cluster.yaml

# Monitor pod scheduling
kubectl get pods -n kafka -o wide -w
```

### Step 4: Verify Placement

```bash
# Check which nodes Kafka pods are running on
kubectl get pods -n kafka -o wide | grep kafka-cluster-kafka

# Should show pods distributed across your labeled nodes
```

## Troubleshooting

### Pods Stuck in Pending

**Symptom**: Kafka pods show `Pending` status

**Cause**: No nodes with `node-role.kubernetes.io/kafka=true` label

**Solution**:
```bash
# Check pod events
kubectl describe pod kafka-cluster-kafka-0 -n kafka

# Label at least 3 nodes
kubectl label nodes <node-1> <node-2> <node-3> node-role.kubernetes.io/kafka=true
```

### Pods Not Evenly Distributed

**Symptom**: Multiple Kafka pods on same node

**Cause**: Not enough labeled nodes or pod anti-affinity not working

**Solution**:
```bash
# Ensure you have at least 3 labeled nodes
kubectl get nodes -l node-role.kubernetes.io/kafka=true

# Check pod anti-affinity is configured
kubectl get kafka kafka-cluster -n kafka -o yaml | grep -A 20 affinity
```

### Performance Issues

**Symptom**: High latency or low throughput

**Cause**: Nodes not optimized for Kafka workloads

**Solution**:
1. Apply OS-level tuning (see above)
2. Use nodes with SSD storage
3. Ensure sufficient network bandwidth
4. Monitor resource usage:
```bash
kubectl top nodes
kubectl top pods -n kafka
```

## Multi-Zone Deployment

For high availability across availability zones:

### Label Nodes with Zone Information

```bash
# Nodes are typically auto-labeled by cloud providers
kubectl get nodes -L topology.kubernetes.io/zone

# Example output:
# NAME     STATUS   ZONE
# node-1   Ready    us-east-1a
# node-2   Ready    us-east-1b
# node-3   Ready    us-east-1c
```

### Update Kafka Configuration for Zone Awareness

```yaml
spec:
  kafka:
    template:
      pod:
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchLabels:
                      app: kafka
                  topologyKey: topology.kubernetes.io/zone
```

## Monitoring Node Health

```bash
# Check node status
kubectl get nodes -l node-role.kubernetes.io/kafka=true

# Check node resource usage
kubectl top nodes -l node-role.kubernetes.io/kafka=true

# Check node conditions
kubectl describe nodes -l node-role.kubernetes.io/kafka=true | grep -A 5 Conditions

# View node events
kubectl get events --field-selector involvedObject.kind=Node
```

## References

- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Strimzi Pod Scheduling](https://strimzi.io/docs/operators/latest/configuring.html#assembly-scheduling-str)
- [Kafka Production Checklist](https://docs.confluent.io/platform/current/kafka/deployment.html)
