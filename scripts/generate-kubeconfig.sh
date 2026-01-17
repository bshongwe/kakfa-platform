#!/bin/bash

set -euo pipefail

# Generate kubeconfig for CI/CD pipeline
ENVIRONMENT=${1:-"dev"}

echo "🔧 Generating kubeconfig for CI/CD ($ENVIRONMENT environment)..."

# Create service account for CI/CD
SA_NAME="kafka-cicd-${ENVIRONMENT}"
kubectl create serviceaccount $SA_NAME -n kube-system --dry-run=client -o yaml | kubectl apply -f -

# Create cluster role binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${SA_NAME}-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $SA_NAME
  namespace: kube-system
EOF

# Get service account token
SECRET_NAME=$(kubectl get serviceaccount $SA_NAME -n kube-system -o jsonpath='{.secrets[0].name}' 2>/dev/null || echo "")

if [ -z "$SECRET_NAME" ]; then
  # For Kubernetes 1.24+ - create token manually
  kubectl create token $SA_NAME -n kube-system --duration=8760h > /tmp/sa-token
  TOKEN=$(cat /tmp/sa-token)
  rm /tmp/sa-token
else
  # For older Kubernetes versions
  TOKEN=$(kubectl get secret $SECRET_NAME -n kube-system -o jsonpath='{.data.token}' | base64 -d)
fi

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Generate kubeconfig
OUTPUT_FILE="kubeconfig-${ENVIRONMENT}.yaml"
cat > $OUTPUT_FILE <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CLUSTER_CA
    server: $CLUSTER_SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SA_NAME
  name: ${SA_NAME}-context
current-context: ${SA_NAME}-context
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo "✅ Generated $OUTPUT_FILE"
echo ""
echo "📋 Base64 encoded for GitHub Secrets:"
echo "$(cat $OUTPUT_FILE | base64 -w 0)"
echo ""
echo "📝 GitHub Secret Name: KUBECONFIG_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"
echo ""
echo "⚠️  Remember to delete $OUTPUT_FILE after adding to GitHub!"