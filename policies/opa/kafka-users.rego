# OPA Policy: Kafka User & ACL Governance
# Enforces security best practices for KafkaUser resources

package kafka.users

# ============================================
# USER NAMING CONVENTIONS
# ============================================

# Rule: User names must follow service-name pattern
deny[msg] {
    input.kind == "KafkaUser"
    user_name := input.metadata.name
    not regex.match(`^[a-z]+-service$`, user_name)
    msg := sprintf("User '%s' must follow pattern: {service-name}-service (e.g., payments-service)", [user_name])
}

# ============================================
# AUTHENTICATION
# ============================================

# Rule: All users must use TLS authentication
deny[msg] {
    input.kind == "KafkaUser"
    auth_type := input.spec.authentication.type
    auth_type != "tls"
    msg := sprintf("User '%s' must use TLS authentication (has: %s)", [input.metadata.name, auth_type])
}

# Rule: Production users must not use SCRAM-SHA-256 (enforce mTLS)
deny[msg] {
    input.kind == "KafkaUser"
    input.metadata.labels.environment == "production"
    auth_type := input.spec.authentication.type
    auth_type == "scram-sha-256"
    msg := sprintf("Production user '%s' must use TLS (mutual TLS required)", [input.metadata.name])
}

# ============================================
# ACL PERMISSIONS
# ============================================

# Rule: Users must not have wildcard topic permissions
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "topic"
    acl.resource.name == "*"
    msg := sprintf("User '%s' must not have wildcard (*) topic access - use explicit topic names", [input.metadata.name])
}

# Rule: Only audit service can read from all topics
deny[msg] {
    input.kind == "KafkaUser"
    input.metadata.name != "audit-service"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "topic"
    acl.resource.patternType == "prefix"
    acl.resource.name == ""
    msg := sprintf("User '%s' cannot have prefix-match on all topics (reserved for audit-service)", [input.metadata.name])
}

# Rule: Write permissions require explicit justification
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.operation == "Write"
    not input.metadata.annotations["kafka.io/write-justification"]
    msg := sprintf("User '%s' requires 'kafka.io/write-justification' annotation for Write permissions", [input.metadata.name])
}

# Rule: Delete operation should never be granted
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.operation == "Delete"
    msg := sprintf("User '%s' cannot have Delete operation (admin-only)", [input.metadata.name])
}

# Rule: Alter operation should be restricted
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.operation == "Alter"
    not input.metadata.labels.admin == "true"
    msg := sprintf("User '%s' cannot have Alter operation (admin-only)", [input.metadata.name])
}

# ============================================
# RESOURCE QUOTAS
# ============================================

# Rule: Production users must have quotas
deny[msg] {
    input.kind == "KafkaUser"
    input.metadata.labels.environment == "production"
    not input.spec.quotas
    msg := sprintf("Production user '%s' must have resource quotas defined", [input.metadata.name])
}

# Rule: Producer quota must not exceed 50 MB/s
deny[msg] {
    input.kind == "KafkaUser"
    producer_quota := input.spec.quotas.producerByteRate
    producer_quota > 52428800  # 50 MB/s in bytes
    msg := sprintf("User '%s' producer quota (%d bytes/s) exceeds limit (50 MB/s)", [input.metadata.name, producer_quota])
}

# Rule: Consumer quota must not exceed 100 MB/s
deny[msg] {
    input.kind == "KafkaUser"
    consumer_quota := input.spec.quotas.consumerByteRate
    consumer_quota > 104857600  # 100 MB/s in bytes
    msg := sprintf("User '%s' consumer quota (%d bytes/s) exceeds limit (100 MB/s)", [input.metadata.name, consumer_quota])
}

# Rule: Request quota must be set
warn[msg] {
    input.kind == "KafkaUser"
    not input.spec.quotas.requestPercentage
    msg := sprintf("User '%s' should set requestPercentage quota (recommended: 50-100)", [input.metadata.name])
}

# ============================================
# CONSUMER GROUP PERMISSIONS
# ============================================

# Rule: Consumer group must match service name
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "group"
    group_name := acl.resource.name
    user_name := input.metadata.name
    not startswith(group_name, user_name)
    msg := sprintf("User '%s' consumer group '%s' must start with user name", [user_name, group_name])
}

# Rule: Wildcard consumer groups not allowed
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "group"
    acl.resource.name == "*"
    msg := sprintf("User '%s' cannot use wildcard consumer group", [input.metadata.name])
}

# ============================================
# TRANSACTIONAL PERMISSIONS
# ============================================

# Rule: Transactional.id must match service name
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "transactionalId"
    tx_id := acl.resource.name
    user_name := input.metadata.name
    not startswith(tx_id, user_name)
    msg := sprintf("User '%s' transactionalId '%s' must start with user name", [user_name, tx_id])
}

# Rule: Only approved services can use transactions
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "transactionalId"
    not input.metadata.labels["kafka.io/transactions-approved"] == "true"
    msg := sprintf("User '%s' requires 'kafka.io/transactions-approved=true' label for transactional access", [input.metadata.name])
}

# ============================================
# LABELS & METADATA
# ============================================

# Rule: Users must have required labels
deny[msg] {
    input.kind == "KafkaUser"
    required_labels := {"team", "service", "environment"}
    missing := {label | required_labels[label]; not input.metadata.labels[label]}
    count(missing) > 0
    msg := sprintf("User '%s' missing required labels: %v", [input.metadata.name, missing])
}

# Rule: Service label must match username
deny[msg] {
    input.kind == "KafkaUser"
    service := input.metadata.labels.service
    user_name := input.metadata.name
    not startswith(user_name, service)
    msg := sprintf("User '%s' service label '%s' must match username prefix", [user_name, service])
}

# ============================================
# DOMAIN SEGREGATION
# ============================================

# Rule: Users can only access their domain topics
deny[msg] {
    input.kind == "KafkaUser"
    user_domain := input.metadata.labels.domain
    acl := input.spec.authorization.acls[_]
    acl.resource.type == "topic"
    topic_name := acl.resource.name
    topic_domain := split(topic_name, ".")[0]
    
    # Allow access to own domain and audit (everyone can write audit)
    user_domain != topic_domain
    topic_domain != "audit"
    
    # Special case: ledger can read from payments
    not cross_domain_allowed(user_domain, topic_domain)
    
    msg := sprintf("User '%s' (domain: %s) cannot access topic '%s' (domain: %s)", 
                   [input.metadata.name, user_domain, topic_name, topic_domain])
}

# Define allowed cross-domain access
cross_domain_allowed(from_domain, to_domain) {
    from_domain == "ledger"
    to_domain == "payments"
}

cross_domain_allowed(from_domain, to_domain) {
    from_domain == "notifications"
    to_domain in {"payments", "ledger"}
}

# ============================================
# SECURITY BEST PRACTICES
# ============================================

# Rule: Production users must have annotations
deny[msg] {
    input.kind == "KafkaUser"
    input.metadata.labels.environment == "production"
    required_annotations := {"kafka.io/owner-email", "kafka.io/oncall-team"}
    missing := {annot | required_annotations[annot]; not input.metadata.annotations[annot]}
    count(missing) > 0
    msg := sprintf("Production user '%s' missing required annotations: %v", [input.metadata.name, missing])
}

# Rule: Sensitive operations require approval annotation
deny[msg] {
    input.kind == "KafkaUser"
    acl := input.spec.authorization.acls[_]
    acl.operation in {"Alter", "AlterConfigs", "ClusterAction"}
    not input.metadata.annotations["kafka.io/security-approval"]
    msg := sprintf("User '%s' requires 'kafka.io/security-approval' for sensitive operations", [input.metadata.name])
}
