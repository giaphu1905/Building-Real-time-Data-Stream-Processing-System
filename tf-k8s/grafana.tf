resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  depends_on = [
    kubernetes_stateful_set.cassandra,
    kubernetes_config_map.grafana-dashboard-pipeline,
    kubernetes_config_map.grafana-provisioning-datasources,
    kubernetes_config_map.grafana-provisioning-dashboards,
    kubernetes_persistent_volume_claim.grafana-volume
  ]

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          pipeline-network = "true"
          app = "grafana"
        }
      }

      spec {
        volume {
          name = "grafana-dashboard-pipeline"

          config_map {
            name = "grafana-dashboard-pipeline"
          }
        }
        volume {
          name = "grafana-provisioning-datasources"

          config_map {
            name = "grafana-provisioning-datasources"
          }
        }
        volume {
          name = "grafana-provisioning-dashboards"

          config_map {
            name = "grafana-provisioning-dashboards"
          }
        }
        volume {
          name = "grafana-volume"
          persistent_volume_claim {
            claim_name = "grafana-volume"
          }
        }
        container {
          name  = "grafana"
          image = "grafana/grafana:11.3.2"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 3000
          }
          
          # Mount PVC
          volume_mount {
            name      = "grafana-volume"
            mount_path = "/var/lib/grafana"
          }
          
          # Mount dashboards
          volume_mount {
            name       = "grafana-dashboard-pipeline"
            mount_path = "/var/lib/grafana/dashboards"
          }
          volume_mount {
            name       = "grafana-provisioning-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }
          volume_mount {
            name       = "grafana-provisioning-dashboards"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }
          env {
            name  = "GF_INSTALL_PLUGINS"
            value = "hadesarchitect-cassandra-datasource"
          }
          env {
            name  = "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH"
            value = "/var/lib/grafana/dashboards/dashboard_pipeline.json"
          }
          env {
            name  = "GF_DASHBOARDS_MIN_REFRESH_INTERVAL"
            value = "1s"  # Thêm giá trị thời gian tối thiểu (ví dụ: 10 giây)
          }
          
        }
        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  depends_on = [
    kubernetes_deployment.grafana
  ]

  spec {
    port {
      name        = "grafana"
      port        = 3000
      target_port = "3000"
    }

    selector = {
      app = "grafana"
    }
    type = "ClusterIP"
  }
}

