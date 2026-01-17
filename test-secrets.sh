#!/bin/bash

cd /Users/ernie-dev/Documents/kakfa-platform

echo "🔐 Testing secret scanner..."
SECRETS_FOUND=0

# Search for password/secret/apikey followed by actual values
if grep -rE "(password|secret|apikey):" platform/ --include="*.yaml" | \
   grep -vE '\$\{' | \
   grep -v "kind: Secret" | \
   grep -v "^[[:space:]]*#" | \
   grep -v "ssl\.(truststore|keystore)" | \
   grep -v "resources:.*secrets" | \
   grep -vE "(password|secret|apikey):\s*$" > /tmp/potential_secrets.txt; then
  
  # Check if any matches actually have values (not just keys)
  if [ -s /tmp/potential_secrets.txt ]; then
    echo "Found potential issues:"
    cat /tmp/potential_secrets.txt
    echo ""
    echo "❌ Found potential hardcoded secrets!"
    SECRETS_FOUND=1
  fi
fi

if [ $SECRETS_FOUND -eq 0 ]; then
  echo "✅ No hardcoded secrets found"
  exit 0
else
  exit 1
fi
