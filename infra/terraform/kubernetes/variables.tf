variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kafka_replicas" {
  description = "Number of Kafka broker replicas"
  type        = number
  default     = 3
}

variable "zookeeper_replicas" {
  description = "Number of Zookeeper replicas"
  type        = number
  default     = 3
}
