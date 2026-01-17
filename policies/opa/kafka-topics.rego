# OPA Policy: Kafka Topic Governance
# Enforces naming conventions, partition limits, and replication standards

package kafka.topics

# ============================================
# TOPIC NAMING CONVENTIONS
# ============================================

# Rule: Topics must follow domain.entity naming pattern
deny contains msg if {
    input.kind == "KafkaTopic"
    topic_name := input.metadata.name
    not regex.match(`^[a-z]+\.[a-z-]+$`, topic_name)
    msg := sprintf("Topic '%s' must follow pattern: domain.entity (e.g., payments.commands)", [topic_name])
}

# Rule: Topics must not contain uppercase letters
deny contains msg if {
    input.kind == "KafkaTopic"
    topic_name := input.metadata.name
    regex.match(`[A-Z]`, topic_name)
    msg := sprintf("Topic '%s' must not contain uppercase letters", [topic_name])
}

# Rule: Topics must not exceed 255 characters
deny contains msg if {
    input.kind == "KafkaTopic"
    topic_name := input.metadata.name
    count(topic_name) > 255
    msg := sprintf("Topic '%s' exceeds 255 character limit", [topic_name])
}

# ============================================
# PARTITION LIMITS
# ============================================

# Rule: Topics must not exceed 50 partitions (prevent over-partitioning)
deny contains msg if {
    input.kind == "KafkaTopic"
    partitions := input.spec.partitions
    partitions > 50
    msg := sprintf("Topic '%s' has %d partitions (max: 50). Over-partitioning degrades performance.", [input.metadata.name, partitions])
}

# Rule: Topics must have at least 3 partitions for production
deny contains msg if {
    input.kind == "KafkaTopic"
    partitions := input.spec.partitions
    partitions < 3
    input.metadata.labels.environment == "production"
    msg := sprintf("Topic '%s' must have at least 3 partitions in production (has: %d)", [input.metadata.name, partitions])
}

# Rule: Partition count must be power of 2 for optimal distribution
warn contains msg if {
    input.kind == "KafkaTopic"
    partitions := input.spec.partitions
    not is_power_of_two(partitions)
    msg := sprintf("Topic '%s' should use power-of-2 partitions (%d is not optimal for key distribution)", [input.metadata.name, partitions])
}

is_power_of_two(n) if {
    n > 0
    bits.and(n, n - 1) == 0
}

# ============================================
# REPLICATION FACTOR
# ============================================

# Rule: Replication factor must be at least 3 for production
deny contains msg if {
    input.kind == "KafkaTopic"
    replication := input.spec.replicas
    replication < 3
    input.metadata.labels.environment == "production"
    msg := sprintf("Topic '%s' must have replication factor >= 3 in production (has: %d)", [input.metadata.name, replication])
}

# Rule: Replication factor must not exceed broker count
deny contains msg if {
    input.kind == "KafkaTopic"
    replication := input.spec.replicas
    replication > 3  # Assuming 3 brokers
    msg := sprintf("Topic '%s' replication factor (%d) exceeds broker count (3)", [input.metadata.name, replication])
}

# Rule: min.insync.replicas must be at least 2 for production
deny contains msg if {
    input.kind == "KafkaTopic"
    input.metadata.labels.environment == "production"
    min_isr := to_number(input.spec.config["min.insync.replicas"])
    min_isr < 2
    msg := sprintf("Topic '%s' must have min.insync.replicas >= 2 in production (has: %d)", [input.metadata.name, min_isr])
}

# ============================================
# RETENTION POLICIES
# ============================================

# Rule: Audit topics must have at least 7 years retention
deny contains msg if {
    input.kind == "KafkaTopic"
    startswith(input.metadata.name, "audit.")
    retention_ms := to_number(input.spec.config["retention.ms"])
    seven_years_ms := 220752000000  # 7 years in milliseconds
    retention_ms < seven_years_ms
    msg := sprintf("Audit topic '%s' must have >= 7 years retention for compliance", [input.metadata.name])
}

# Rule: Ledger topics must have infinite retention
deny contains msg if {
    input.kind == "KafkaTopic"
    startswith(input.metadata.name, "ledger.")
    retention_ms := to_number(input.spec.config["retention.ms"])
    retention_ms != -1
    msg := sprintf("Ledger topic '%s' must have infinite retention (retention.ms=-1)", [input.metadata.name])
}

# Rule: Non-critical topics should not exceed 90 days retention (cost optimization)
warn contains msg if {
    input.kind == "KafkaTopic"
    not startswith(input.metadata.name, "audit.")
    not startswith(input.metadata.name, "ledger.")
    retention_ms := to_number(input.spec.config["retention.ms"])
    ninety_days_ms := 7776000000  # 90 days
    retention_ms > ninety_days_ms
    msg := sprintf("Topic '%s' has >90 days retention. Consider tiered storage for cost optimization.", [input.metadata.name])
}

# ============================================
# COMPRESSION
# ============================================

# Rule: Audit and ledger topics must not use compression (integrity)
deny contains msg if {
    input.kind == "KafkaTopic"
    topic_is_compliance(input.metadata.name)
    compression := input.spec.config["compression.type"]
    compression != "uncompressed"
    msg := sprintf("Compliance topic '%s' must not use compression (integrity requirement)", [input.metadata.name])
}

topic_is_compliance(name) if {
    startswith(name, "audit.")
}

topic_is_compliance(name) if {
    startswith(name, "ledger.")
}

# ============================================
# DOMAIN RESTRICTIONS
# ============================================

# Rule: Only approved domains are allowed
deny contains msg if {
    input.kind == "KafkaTopic"
    topic_name := input.metadata.name
    domain := split(topic_name, ".")[0]
    not domain in {"payments", "ledger", "notifications", "audit", "analytics", "risk"}
    msg := sprintf("Topic '%s' uses unapproved domain '%s'. Approved: payments, ledger, notifications, audit, analytics, risk", [topic_name, domain])
}

# ============================================
# LABELS & METADATA
# ============================================

# Rule: Topics must have required labels
deny contains msg if {
    input.kind == "KafkaTopic"
    required_labels := {"domain", "owner", "environment"}
    missing := {label | required_labels[label]; not input.metadata.labels[label]}
    count(missing) > 0
    msg := sprintf("Topic '%s' missing required labels: %v", [input.metadata.name, missing])
}

# Rule: Owner label must be valid team
deny contains msg if {
    input.kind == "KafkaTopic"
    owner := input.metadata.labels.owner
    not owner in {"platform", "payments", "ledger", "notifications", "audit", "analytics"}
    msg := sprintf("Topic '%s' has invalid owner '%s'", [input.metadata.name, owner])
}

# ============================================
# CLEANUP POLICY
# ============================================

# Rule: Compacted topics must have key
deny contains msg if {
    input.kind == "KafkaTopic"
    cleanup := input.spec.config["cleanup.policy"]
    cleanup == "compact"
    not input.spec.config["compression.type"]
    msg := sprintf("Compacted topic '%s' should specify compression for efficiency", [input.metadata.name])
}

# Rule: Balance topics must use log compaction
deny contains msg if {
    input.kind == "KafkaTopic"
    contains(input.metadata.name, "balance")
    cleanup := input.spec.config["cleanup.policy"]
    cleanup != "compact"
    msg := sprintf("Balance topic '%s' must use cleanup.policy=compact", [input.metadata.name])
}

# ============================================
# SECURITY
# ============================================

# Rule: Production topics must not allow unauthenticated access
deny contains msg if {
    input.kind == "KafkaTopic"
    input.metadata.labels.environment == "production"
    not input.metadata.annotations["strimzi.io/acl"]
    msg := sprintf("Production topic '%s' must have ACL annotations", [input.metadata.name])
}

# ============================================
# HELPER FUNCTIONS
# ============================================

# Convert value to number safely
to_number(value) = num if {
    is_number(value)
    num := value
}
