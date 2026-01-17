#!/bin/bash

set -euo pipefail

echo "🔐 Setting up GitHub Secrets for Kafka Platform CI/CD"
echo ""
echo "This script will help you set up all required secrets for the CI/CD pipeline."
echo ""

# Function to generate kubeconfig for environment
generate_env_config() {
  local env=$1
  echo "🔧 Generating kubeconfig for $env environment..."
  
  if ./scripts/generate-kubeconfig.sh $env; then
    echo "✅ Generated kubeconfig-${env}.yaml"
    return 0
  else
    echo "❌ Failed to generate kubeconfig for $env"
    return 1
  fi
}

# Check if we're in the right directory
if [ ! -f "scripts/generate-kubeconfig.sh" ]; then
  echo "❌ Please run this script from the kafka-platform root directory"
  exit 1
fi

echo "Select which environments to configure:"
echo "1) Development only"
echo "2) Development + Staging"
echo "3) All environments (Dev + Staging + Production)"
echo "4) Custom environment"
read -p "Enter choice (1-4): " choice

case $choice in
  1)
    ENVIRONMENTS=("dev")
    ;;
  2)
    ENVIRONMENTS=("dev" "staging")
    ;;
  3)
    ENVIRONMENTS=("dev" "staging" "prod")
    ;;
  4)
    read -p "Enter environment name: " custom_env
    ENVIRONMENTS=("$custom_env")
    ;;
  *)
    echo "❌ Invalid choice"
    exit 1
    ;;
esac

echo ""
echo "🔄 Generating kubeconfigs..."

# Generate kubeconfigs for selected environments
for env in "${ENVIRONMENTS[@]}"; do
  if ! generate_env_config $env; then
    echo "❌ Failed to generate config for $env environment"
    exit 1
  fi
  echo ""
done

echo "📋 GitHub Secrets Configuration"
echo "============================================"
echo ""
echo "Go to: GitHub repo > Settings > Secrets and variables > Actions"
echo ""
echo "Add these Repository Secrets:"
echo ""

# Display secrets for each environment
for env in "${ENVIRONMENTS[@]}"; do
  config_file="kubeconfig-${env}.yaml"
  if [ -f "$config_file" ]; then
    secret_name="KUBECONFIG_$(echo $env | tr '[:lower:]' '[:upper:]')"
    b64_content=$(cat $config_file | base64 -w 0)
    
    echo "Secret Name: $secret_name"
    echo "Description: Kubernetes config for $env environment"
    echo "Value:"
    echo "$b64_content"
    echo ""
    echo "---"
    echo ""
  fi
done

# Additional optional secrets
echo "Optional Secrets:"
echo ""
echo "Secret Name: SLACK_WEBHOOK"
echo "Description: Slack webhook URL for deployment notifications"
echo "Value: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
echo ""
echo "Secret Name: DOCKER_REGISTRY"
echo "Description: Container registry for custom images"
echo "Value: your-registry.com/kafka-platform"
echo ""

echo "✅ Configuration complete!"
echo ""
echo "🧹 Cleanup:"
for env in "${ENVIRONMENTS[@]}"; do
  config_file="kubeconfig-${env}.yaml"
  if [ -f "$config_file" ]; then
    echo "   rm $config_file  # Delete after adding to GitHub"
  fi
done
echo ""
echo "🚀 Test the pipeline:"
echo "   git push origin main  # Trigger the workflow"
echo ""
echo "For more details, see: .github/workflows/kafka-deploy.yml"