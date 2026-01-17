# Kafka Platform

A production-ready Kafka platform with infrastructure as code, observability, and security.

## Structure

- **infra/** - Infrastructure provisioning with Terraform
- **platform/** - Kafka cluster configurations and components
- **observability/** - Monitoring and alerting setup
- **security/** - Security configurations, certificates, and ACLs
- **ci-cd/** - CI/CD pipelines and GitOps configurations
- **docs/** - Additional documentation

## Getting Started

### Quick Install (5 Minutes)

```bash
# 1. Install Strimzi Kafka Operator
./scripts/install-strimzi.sh

# 2. Label nodes for Kafka workloads
./scripts/label-kafka-nodes.sh node-1 node-2 node-3

# 3. Deploy Kafka cluster
kubectl apply -f platform/kafka/cluster.yaml

# 4. Create topics and users
kubectl apply -f platform/kafka/topics/
kubectl apply -f platform/kafka/users/
```

### Full Installation

1. **Install Strimzi operator** (see [Manual Installation](docs/MANUAL_INSTALLATION.md))
   ```bash
   kubectl create namespace kafka
   kubectl apply -f https://strimzi.io/install/latest?namespace=kafka
   ```
   Or use the script:
   ```bash
   ./scripts/install-strimzi.sh
   ```

2. **Label Kubernetes nodes** for Kafka workloads (see [Node Configuration](docs/NODE_CONFIGURATION.md))
   ```bash
   ./scripts/label-kafka-nodes.sh node-1 node-2 node-3
   ```

3. Configure your environment in `infra/environments/` (if using Terraform)

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

- 📘 [Manual Installation Guide](docs/MANUAL_INSTALLATION.md) - Step-by-step installation without Terraform
- 🚀 [Quick Start Guide](docs/QUICKSTART.md) - 5-minute deployment guide
- 🏗️ [Architecture Documentation](docs/ARCHITECTURE.md) - Platform architecture and components
- 🖥️ [Node Configuration Guide](docs/NODE_CONFIGURATION.md) - Node labeling and optimization
- 📊 [Node Affinity Implementation](docs/NODE_AFFINITY_IMPLEMENTATION.md) - Node scheduling details
- 📝 [Getting Started (Detailed)](docs/GETTING_STARTED.md) - Comprehensive setup guide

### Installation Methods

| Method | Use Case | Documentation |
|--------|----------|---------------|
| **Complete Script** | Fastest way to get started | `./scripts/complete-install.sh --help` |
| **Manual Commands** | Step-by-step control | [MANUAL_INSTALLATION.md](docs/MANUAL_INSTALLATION.md) |
| **Terraform** | Infrastructure as Code | [GETTING_STARTED.md](docs/GETTING_STARTED.md) |

## Documentation
