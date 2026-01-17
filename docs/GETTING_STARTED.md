# Getting Started with Kafka Platform

## Prerequisites

Before deploying the Kafka platform, ensure you have:

1. **Kubernetes Cluster** (v1.24+)
   - Minimum 3 worker nodes
   - At least 16GB RAM and 4 CPUs per node
   - Storage provisioner configured

2. **Tools**
   - `kubectl` (v1.24+)
   - `terraform` (v1.0+)
   - `helm` (v3.0+)
   - `git`

3. **Access**
   - Kubernetes cluster admin access
   - Container registry access (if using private images)

## Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd kafka-platform
```

### 2. Configure Your Environment

Choose your environment (dev, staging, or prod) and review the configuration:

```bash
cd infra/environments/dev
vi terraform.tfvars
```

### 3. Deploy Infrastructure

```bash
cd ../../terraform/kubernetes
terraform init
terraform plan -var-file=../../environments/dev/terraform.tfvars
terraform apply -var-file=../../environments/dev/terraform.tfvars
```

This will:
- Create the `kafka` namespace
- Deploy the Strimzi Kafka Operator
- Create the `monitoring` namespace

### 4. Deploy Kafka Cluster

Wait for the Strimzi operator to be ready:

```bash
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s
```

Deploy the Kafka cluster:

```bash
kubectl apply -f ../../../platform/kafka/cluster.yaml
```

Wait for Kafka to be ready:

```bash
kubectl wait kafka/kafka-cluster --for=condition=Ready --timeout=600s -n kafka
```

### 5. Create Topics

```bash
kubectl apply -f ../../../platform/kafka/topics/
```

### 6. Create Users

```bash
kubectl apply -f ../../../platform/kafka/users/
```

### 7. Deploy Schema Registry

```bash
kubectl apply -f ../../../platform/schema-registry/schema-registry.yaml
```

### 8. Deploy Monitoring

```bash
# Create Prometheus
kubectl apply -f ../../../observability/prometheus/prometheus.yaml

# Create PVC for Prometheus
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF

# Create Grafana secret
kubectl create secret generic grafana-admin \
  --from-literal=password=admin123 \
  -n monitoring

# Create PVC for Grafana
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# Deploy Grafana
kubectl apply -f ../../../observability/grafana/grafana.yaml

# Deploy alert rules
kubectl apply -f ../../../observability/alerts/kafka-alerts.yaml
```

## Verification

### Check Kafka Cluster Status

```bash
kubectl get kafka -n kafka
kubectl get kafkatopic -n kafka
kubectl get kafkauser -n kafka
```

### Check Pods

```bash
kubectl get pods -n kafka
kubectl get pods -n monitoring
```

### Access Grafana

Get the Grafana service:

```bash
kubectl get svc grafana -n monitoring
```

If using LoadBalancer, get the external IP and access Grafana at `http://<EXTERNAL-IP>:3000`

Default credentials:
- Username: `admin`
- Password: `admin123` (change this in production!)

## Testing

### Produce Messages

Create a producer pod:

```bash
kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \
  --rm=true --restart=Never -n kafka -- bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic example-topic
```

### Consume Messages

In another terminal, create a consumer pod:

```bash
kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \
  --rm=true --restart=Never -n kafka -- bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic example-topic \
  --from-beginning
```

## Next Steps

1. **Security**: Configure TLS certificates and ACLs
2. **Monitoring**: Import Kafka dashboards into Grafana
3. **CI/CD**: Set up GitHub Actions or ArgoCD
4. **Backup**: Configure backup strategies
5. **Scaling**: Adjust replicas and resources based on load

## Troubleshooting

### Operator Not Starting

```bash
kubectl logs -l name=strimzi-cluster-operator -n kafka
```

### Kafka Pods Not Ready

```bash
kubectl describe pod kafka-cluster-kafka-0 -n kafka
kubectl logs kafka-cluster-kafka-0 -n kafka
```

### Topic Not Created

```bash
kubectl describe kafkatopic example-topic -n kafka
```

## Clean Up

To remove all resources:

```bash
kubectl delete -f ../../../platform/kafka/users/
kubectl delete -f ../../../platform/kafka/topics/
kubectl delete -f ../../../platform/kafka/cluster.yaml
kubectl delete -f ../../../platform/schema-registry/
kubectl delete -f ../../../observability/

cd infra/terraform/kubernetes
terraform destroy -var-file=../../environments/dev/terraform.tfvars
```

## Support

For issues or questions:
- Check the [Architecture documentation](./ARCHITECTURE.md)
- Review [Strimzi documentation](https://strimzi.io/docs/)
- Check Kafka logs and operator logs
