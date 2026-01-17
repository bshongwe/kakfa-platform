# Kafka ACL Configuration

This directory contains Access Control List (ACL) configurations for Kafka.

## Overview

ACLs in Kafka define permissions for users and groups to perform operations on resources (topics, consumer groups, etc.).

## Usage

ACLs are managed through KafkaUser resources in the `platform/kafka/users/` directory.

Example ACL operations:
- Read
- Write
- Create
- Delete
- Alter
- Describe
- ClusterAction
- DescribeConfigs
- AlterConfigs

## Best Practices

1. Follow the principle of least privilege
2. Use specific topic names instead of wildcards when possible
3. Regularly audit ACL configurations
4. Document the purpose of each ACL rule
5. Use consumer group patterns for better organization

## Example ACL Structure

```yaml
acls:
  - resource:
      type: topic
      name: my-topic
      patternType: literal
    operations:
      - Read
      - Write
    host: "*"
```

## Resources

- [Strimzi ACL Documentation](https://strimzi.io/docs/operators/latest/configuring.html#type-AclRule-reference)
- [Kafka Authorization](https://kafka.apache.org/documentation/#security_authz)
