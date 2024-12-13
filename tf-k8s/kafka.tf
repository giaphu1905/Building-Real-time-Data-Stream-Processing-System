###################k8s-stateful_set####################
resource "kubernetes_stateful_set" "kafka" {
  metadata {
    name = "kafka"
    namespace = var.namespace
    labels = {
      app = "kafka"
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim.kafka-volume,
    kubernetes_persistent_volume.kafka-volume
  ]

  spec {
    service_name = "kafka-service"
    replicas = 1

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          pipeline-network = "true"

          app = "kafka"
        }
      }

      spec {
        volume {
          name = "kafka-volume"

          persistent_volume_claim {
            claim_name = "kafka-volume"
          }
        }
        container {
          name  = "kafka"
          image = "confluentinc/cp-kafka:7.8.0"
          port {
            container_port = 9092
          }

          port {
            container_port = 29092
          }

          env {
            name  = "KAFKA_PROCESS_ROLES"
            value = "broker,controller"
          }

          env {
            name = "KAFKA_CONTROLLER_QUORUM_VOTERS"
            value = "1@localhost:29093"
          }

          env {
            name  = "KAFKA_LISTENERS"
            value = "PLAINTEXT://localhost:29092,PLAINTEXT_HOST://0.0.0.0:9092,CONTROLLER://localhost:29093"
          }

          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://localhost:29092,PLAINTEXT_HOST://kafka-service.${var.namespace}.svc.cluster.local:9092"
          }

          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
          }

          env {
            name = "KAFKA_CONTROLLER_LISTENER_NAMES"
            value = "CONTROLLER"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }

          env {
            name = "CLUSTER_ID"
            value = "cluster-kafka-id"
          }
          env {
            name = "KAFKA_NODE_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_BROKER_ID"
            value = "1"
          }

          env {
            name  = "KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS"
            value = "0"
          }

          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }

          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }

          volume_mount {
            name       = "kafka-volume"
            mount_path = "/var/data"
          }          
        }

        container {
          name  = "kafka-ui"
          image = "provectuslabs/kafka-ui:v0.7.2"

          port {
            container_port = 8080
          }

          env {
            name  = "KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS"
            value = "localhost:29092"
          }
          env {
            name  = "DYNAMIC_CONFIG_ENABLED"
            value = "true"
          }
        }

        restart_policy = "Always"
        hostname = "kafka-service"
      }
    }
  }
}
######################k8s-service######################
resource "kubernetes_service" "kafka" {
  metadata {
    name = "kafka-service"
    namespace = var.namespace
    labels = {
      app = "kafka"
    }
  }

  depends_on = [
    kubernetes_stateful_set.kafka
  ]

  spec {
    port {
      name        = "kafka-external"
      port        = 9092
      target_port = "9092"
    }

    port {
      name        = "kafka-internal"
      port        = 29092
      target_port = "29092"
    }

    port {
      name        = "kafka-ui"
      port        = 18080
      target_port = "18080"
    }

    selector = {
      app = "kafka"
    }

    cluster_ip = "None"
  }
}
