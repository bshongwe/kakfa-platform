# Kafka Platform Architecture

## Overview

This platform provides a production-ready Apache Kafka deployment on Kubernetes using the Strimzi operator.

## Components

### 1. Kafka Cluster
- **Brokers**: 3 replicas (configurable per environment)
- **Version**: Apache Kafka 3.6.0
- **Listeners**: 
  - Internal plain (9092)
  - Internal TLS (9093)
  - External LoadBalancer with TLS (9094)
- **Storage**: JBOD with persistent volumes (100Gi per broker)

### 2. Zookeeper Ensemble
- **Replicas**: 3 nodes
- **Storage**: 10Gi persistent volumes
- **Purpose**: Cluster coordination and metadata management

### 3. Schema Registry
- **Replicas**: 2 instances for high availability
- **Version**: Confluent Platform 7.5.0
- **Storage**: Uses internal Kafka topic `_schemas`

### 4. Monitoring Stack

#### Prometheus
- Scrapes metrics from Kafka, Zookeeper, and Kafka Exporter
- 15-day retention period
- JMX metrics exported via JMX Exporter

#### Grafana
- Pre-configured dashboards for Kafka monitoring
- Connects to Prometheus datasource
- Visualizes broker health, throughput, latency, and consumer lag

#### Kafka Exporter
- Exports additional consumer group metrics
- Monitors lag and offset information

### 5. Security

#### TLS/SSL
- Mutual TLS authentication for external clients
- Certificate management via cert-manager (optional)
- Encrypted communication between brokers

#### ACLs
- Topic-level access control
- User-based authorization
- Managed via KafkaUser CRDs

### 6. Infrastructure

#### Terraform Modules
- **kubernetes**: Namespace creation, Strimzi operator deployment
- **networking**: Load balancers, ingress configuration
- **storage**: Persistent volume provisioning

#### Environments
- **Dev**: Single broker, minimal resources
- **Staging**: 2 brokers, moderate resources
- **Prod**: 3 brokers, production-grade resources

## Data Flow

```
Producers → Load Balancer (9094) → Kafka Brokers → Topics
                                         ↓
                                   Schema Registry
                                         ↓
                                   Consumers
```

## High Availability

1. **Broker HA**: Minimum 3 brokers with replication factor of 3
2. **Zookeeper HA**: 3-node ensemble
3. **Topic Replication**: Default RF=3, min.insync.replicas=2
4. **Schema Registry**: 2 replicas with load balancing

## Disaster Recovery

1. **Backups**: Regular snapshots of persistent volumes
2. **MirrorMaker**: Cross-cluster replication (optional)
3. **Topic Configuration**: Stored in Git for reproducibility
4. **Monitoring**: Alerts for failures and degraded state

## Scalability

- Horizontal scaling of brokers via cluster.yaml
- Auto-scaling of consumer applications
- Partition count adjustable per topic
- Storage expansion via PVC resize

## Performance Tuning

### Broker Configuration
- `log.segment.bytes`: 1GB
- `num.network.threads`: Auto-configured based on CPU
- `num.io.threads`: Auto-configured based on CPU
- `socket.send.buffer.bytes`: 102400
- `socket.receive.buffer.bytes`: 102400

### Topic Configuration
- `compression.type`: producer
- `max.message.bytes`: 1MB
- `retention.ms`: 7 days (configurable per topic)

## Security Considerations

1. **Network Policies**: Restrict pod-to-pod communication
2. **RBAC**: Kubernetes role-based access control
3. **Secrets Management**: External secrets operator integration
4. **Audit Logging**: Enable Kafka audit logs
5. **Encryption**: At-rest encryption for persistent volumes

## Monitoring & Alerting

### Key Metrics
- Broker availability
- Under-replicated partitions
- Offline partitions
- Consumer lag
- Disk usage
- Network throughput

### Alert Rules
- Critical: Broker down, offline partitions, no active controller
- Warning: Under-replicated partitions, high consumer lag, high disk usage

## Cost Optimization

1. **Resource Requests/Limits**: Right-sized per environment
2. **Storage Classes**: Use appropriate storage tiers
3. **Auto-scaling**: Consumer applications scale based on lag
4. **Retention Policies**: Appropriate retention per topic
5. **Compression**: Enable compression to reduce storage

## Future Enhancements

- [ ] KRaft mode (ZooKeeper-less) migration
- [ ] Multi-region deployment
- [ ] Tiered storage for cold data
- [ ] Advanced security with OAuth/OIDC
- [ ] Custom metrics and dashboards
- [ ] Automated capacity planning
