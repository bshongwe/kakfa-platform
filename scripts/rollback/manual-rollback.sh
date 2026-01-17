#!/bin/bash
#
# Manual Rollback Script
# Use this script to manually rollback Kafka configuration to a previous snapshot
#
# Usage: ./manual-rollback.sh <snapshot-file.tar.gz>

set -euo pipefail

SNAPSHOT_FILE="${1:-}"
NAMESPACE="kafka"

if [ -z "$SNAPSHOT_FILE" ]; then
    echo "❌ Error: Snapshot file required"
    echo "Usage: $0 <snapshot-file.tar.gz>"
    echo ""
    echo "Available snapshots:"
    ls -lh /tmp/rollback-*.tar.gz 2>/dev/null || echo "  No snapshots found in /tmp/"
    exit 1
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "❌ Error: Snapshot file not found: $SNAPSHOT_FILE"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  KAFKA MANUAL ROLLBACK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  WARNING: This will restore Kafka configuration from snapshot"
echo "Snapshot: $SNAPSHOT_FILE"
echo "Namespace: $NAMESPACE"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

echo ""
echo "🔄 Starting rollback..."

# Extract snapshot
TEMP_DIR=$(mktemp -d)
tar -xzf "$SNAPSHOT_FILE" -C "$TEMP_DIR"

SNAPSHOT_DIR=$(find "$TEMP_DIR" -type d -name "rollback-*" | head -1)

if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "❌ Error: Invalid snapshot structure"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "✓ Snapshot extracted to: $SNAPSHOT_DIR"

# Restore topics
if [ -f "$SNAPSHOT_DIR/topics-baseline.yaml" ]; then
    echo "📝 Restoring topics..."
    kubectl apply -f "$SNAPSHOT_DIR/topics-baseline.yaml"
    echo "✓ Topics restored"
else
    echo "⚠️  No topics file found in snapshot"
fi

# Restore users
if [ -f "$SNAPSHOT_DIR/users-baseline.yaml" ]; then
    echo "👤 Restoring users..."
    kubectl apply -f "$SNAPSHOT_DIR/users-baseline.yaml"
    echo "✓ Users restored"
else
    echo "⚠️  No users file found in snapshot"
fi

# Restore cluster config (use with caution!)
if [ -f "$SNAPSHOT_DIR/cluster-baseline.yaml" ]; then
    echo ""
    echo "⚠️  Cluster configuration found in snapshot"
    read -p "Restore cluster configuration? This may cause broker restarts (yes/no): " RESTORE_CLUSTER
    
    if [ "$RESTORE_CLUSTER" = "yes" ]; then
        echo "🔧 Restoring cluster configuration..."
        kubectl apply -f "$SNAPSHOT_DIR/cluster-baseline.yaml"
        echo "✓ Cluster configuration restored"
    else
        echo "Skipped cluster configuration restore"
    fi
fi

echo ""
echo "⏳ Waiting for resources to stabilize..."
sleep 10

echo ""
echo "✅ Rollback complete!"
echo ""
echo "Verify status:"
echo "  kubectl get kafkatopic -n $NAMESPACE"
echo "  kubectl get kafkauser -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE"

# Cleanup
rm -rf "$TEMP_DIR"
