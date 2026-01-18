# CI/CD Setup Guide

This guide walks you through setting up the enterprise-grade CI/CD pipeline for the Kafka Platform.

## Quick Setup

```bash
# 1. Generate kubeconfigs for all environments
./scripts/setup-github-secrets.sh

# 2. Follow the output instructions to add secrets to GitHub

# 3. Test the pipeline
git push origin main
```

## CI/CD Architecture

The platform uses **dual CI/CD approaches**:

1. **GitHub Actions** - Application deployments (microservices, Docker images)
2. **ArgoCD** - Infrastructure deployments (Kafka cluster, GitOps)

### GitHub Actions Workflows

| Workflow | Purpose | Triggers |
|----------|---------|----------|
| `build-packages.yml` | Build & push Docker images | Code changes, releases |
| `release.yml` | Automated releases | Version changes |
| `deploy.yml` | Infrastructure deployment | Infrastructure changes |

### ArgoCD Applications

| Application | Purpose | Sync Wave |
|-------------|---------|----------|
| `kafka-platform` | Kafka cluster & topics | 1 |
| `kafka-monitoring` | Observability stack | 2 |
| `kafka-microservices` | Application deployments | 3 |

## Required Secrets

The CI/CD pipeline expects these secrets in your GitHub repository:

| Secret Name | Environment | Required | Description |
|-------------|-------------|----------|-------------|
| `KUBECONFIG_DEV` | Development | No | Base64 encoded kubeconfig for dev cluster |
| `KUBECONFIG_STAGING` | Staging | No | Base64 encoded kubeconfig for staging cluster |
| `KUBECONFIG_PROD` | Production | Yes* | Base64 encoded kubeconfig for prod cluster |
| `SLACK_WEBHOOK_URL` | All | No | Slack webhook URL for notifications |
| `GITHUB_TOKEN` | All | Auto | Automatically provided by GitHub Actions |

*Required for production deployments

## Enterprise Features

### Security & Compliance
- **Security scanning** with Trivy (SAST)
- **SARIF upload** to GitHub Security tab
- **Policy validation** with OPA
- **Dependency scanning** for vulnerabilities

### Deployment Safety
- **Manual approval gates** for production
- **Pre-deployment backups**
- **Health checks** and verification
- **Automatic rollback** on failure
- **Integration tests** in dev environment

### Observability
- **Slack notifications** for deployment status
- **GitHub Container Registry** for image storage
- **Automated changelog** generation
- **Release notes** with commit history

## Step-by-Step Setup

### 1. Generate Service Account & Kubeconfig

For each environment you want to deploy to:

```bash
# Development environment
./scripts/generate-kubeconfig.sh dev

# Staging environment  
./scripts/generate-kubeconfig.sh staging

# Production environment
./scripts/generate-kubeconfig.sh prod
```

This creates:
- Service account `kafka-cicd-{env}` in `kube-system` namespace
- ClusterRoleBinding with `cluster-admin` permissions
- Kubeconfig file `kubeconfig-{env}.yaml`

### 2. Add Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add each secret:

```bash
# Get base64 encoded kubeconfig
cat kubeconfig-dev.yaml | base64 -w 0
```

**Secret Configuration:**
- **Name**: `KUBECONFIG_DEV` (or `KUBECONFIG_STAGING`, `KUBECONFIG_PROD`)
- **Value**: Base64 encoded kubeconfig content

### 3. Optional: Slack Notifications

Add Slack webhook for deployment notifications:

1. Create a Slack webhook in your workspace
2. Add secret `SLACK_WEBHOOK` with the webhook URL

### 4. Test the Pipeline

```bash
# Trigger development deployment
git push origin develop

# Trigger staging/production deployment  
git push origin main
```

## Pipeline Behavior

| Branch | Trigger | Environments | Approval Required |
|--------|---------|--------------|-------------------|
| `develop` | Push | Development | No |
| `main` | Push | Staging → Production | No |
| `main` | PR | Validation only | No |

## Deployment Stages

### 1. Validation
- YAML syntax validation
- Kubernetes manifest validation
- Avro schema validation
- OPA policy tests
- Security scanning

### 2. Planning
- Change detection (topics, users, cluster)
- Rollback snapshot creation
- Deployment plan generation

### 3. Development Deployment
- Direct deployment to dev cluster
- Basic health checks

### 4. Staging Deployment (Canary)
- 10% canary deployment
- Health monitoring
- Automatic rollback on failure
- Full deployment on success

### 5. Production Deployment (Blue-Green)
- Blue-green deployment strategy
- Comprehensive health checks
- Automatic rollback on failure
- Smoke tests

## Security Considerations

### Service Account Permissions

The generated service accounts have `cluster-admin` permissions. For production, consider:

1. **Namespace-scoped permissions**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kafka-cicd-binding
  namespace: kafka
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: kafka-cicd-prod
  namespace: kube-system
```

2. **Custom RBAC role** with minimal required permissions:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kafka-deployer
rules:
- apiGroups: ["kafka.strimzi.io"]
  resources: ["kafkas", "kafkatopics", "kafkausers"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
```

### Token Rotation

Service account tokens are long-lived (1 year). Consider:

1. **Regular rotation**:
```bash
# Regenerate token
kubectl create token kafka-cicd-prod -n kube-system --duration=8760h
```

2. **Shorter token duration** for higher security environments

## Troubleshooting

### Common Issues

**1. Pipeline fails with "KUBECONFIG secret not configured"**
- Ensure secret name matches exactly: `KUBECONFIG_DEV`, `KUBECONFIG_STAGING`, `KUBECONFIG_PROD`
- Verify base64 encoding is correct

**2. Authentication failures**
- Check service account exists: `kubectl get sa kafka-cicd-prod -n kube-system`
- Verify ClusterRoleBinding: `kubectl get clusterrolebinding kafka-cicd-prod-binding`

**3. Permission denied errors**
- Service account may need additional permissions
- Check RBAC configuration

### Debug Commands

```bash
# Check service account
kubectl get serviceaccount kafka-cicd-prod -n kube-system -o yaml

# Check permissions
kubectl auth can-i create kafkatopic --as=system:serviceaccount:kube-system:kafka-cicd-prod

# Test kubeconfig
export KUBECONFIG=kubeconfig-prod.yaml
kubectl cluster-info
```

## Cleanup

After adding secrets to GitHub:

```bash
# Remove local kubeconfig files
rm kubeconfig-*.yaml

# Optional: Remove service accounts (if no longer needed)
kubectl delete serviceaccount kafka-cicd-dev -n kube-system
kubectl delete clusterrolebinding kafka-cicd-dev-binding
```

## Next Steps

1. **Set up monitoring**: Configure Prometheus/Grafana for pipeline metrics
2. **Add quality gates**: Implement additional validation steps
3. **Environment promotion**: Set up automated promotion between environments
4. **Disaster recovery**: Test rollback procedures

For more details, see the [CI/CD workflow](.github/workflows/kafka-deploy.yml).