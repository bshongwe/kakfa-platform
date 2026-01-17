terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Create Kafka namespace
resource "kubernetes_namespace" "kafka" {
  metadata {
    name = "kafka"
    labels = {
      name        = "kafka"
      environment = var.environment
    }
  }
}

# Install Strimzi Kafka Operator
resource "helm_release" "strimzi_kafka_operator" {
  name       = "strimzi-kafka-operator"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.38.0"
  namespace  = kubernetes_namespace.kafka.metadata[0].name

  set {
    name  = "watchNamespaces"
    value = "{${kubernetes_namespace.kafka.metadata[0].name}}"
  }

  values = [
    templatefile("${path.module}/values/strimzi-values.yaml", {
      environment = var.environment
    })
  ]
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = var.environment
    }
  }
}
