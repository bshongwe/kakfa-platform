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

1. Configure your environment in `infra/environments/`
2. Deploy infrastructure using Terraform
3. Apply Kafka cluster configuration from `platform/kafka/`
4. Set up observability with Prometheus and Grafana
5. Configure security policies

## Prerequisites

- Kubernetes cluster
- Terraform >= 1.0
- kubectl
- Helm

## Documentation

See the `docs/` directory for detailed documentation.
