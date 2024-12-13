# Triển khai FinnhubProducer
resource "kubernetes_deployment" "finnhub-producer" {
  depends_on = [
    kubernetes_stateful_set.kafka,
    kubernetes_stateful_set.cassandra
  ]
  metadata {
    name      = "finnhub-producer"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "finnhub-producer"
      }
    }

    template {
      metadata {
        labels = {
          app = "finnhub-producer"
          pipeline-network = "true"
        }
      }

      spec {
        container {
          name  = "finnhub-producer"
          image = "20079741phu1905/finnhubproducer:latest" 
          
          env_from {
            config_map_ref {
              name = "pipeline-config"
            }
          }

          env_from {
            secret_ref {
              name = "pipeline-secrets"
            }
          }
        }
        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service" "finnhub-producer" {
  metadata {
    name  = "finnhub-producer"
    namespace = var.namespace
    labels = {
      app = "finnhub-producer"
    }
  }

  depends_on = [
    kubernetes_deployment.finnhub-producer
  ]
  
  spec {
    port {
      name        = "finnhub-producer"
      port        = 8001
      target_port = "8001"
    }

    selector = {
      app = "finnhub-producer"
    }

    cluster_ip = "None"
  }
}