resource "kubernetes_manifest" "stream-processor" {
  depends_on = [
    kubernetes_stateful_set.kafka,
    kubernetes_config_map.pipeline-config,
    kubernetes_secret.pipeline-secrets,
    kubernetes_stateful_set.cassandra,
  ]

  manifest = {
    apiVersion = "sparkoperator.k8s.io/v1beta2"
    kind       = "SparkApplication"

    metadata = {
      name      = "stream-processor"
      namespace = var.namespace
    }

    spec = {
      type = "Python"
      mode = "cluster"
      image = "20079741phu1905/streamprocessor:latest"
      imagePullPolicy = "IfNotPresent"
      mainApplicationFile = "local:///app/src/StreamProcessor.py"
      sparkVersion = "3.4.4"
      restartPolicy = {
        type = "Always"
      }

      driver = {
        cores      = 2
        memory     = "1g"
        serviceAccount = "spark-sa"
        labels = {
          version = "3.4.4"
        }
        envFrom = [
          {
            configMapRef = {
              name = "pipeline-config"
            }
          },
          {
            secretRef = {
              name = "pipeline-secrets"
            }
          }
        ]
      }
      executor = {
        cores      = 2
        instances  = 2
        memory     = "2100m"
        labels = {
          version = "3.4.4"
        }
        envFrom = [
          {
            configMapRef = {
              name = "pipeline-config"
            }
          },
          {
            secretRef = {
              name = "pipeline-secrets"
            }
          }
        ]
      }
    }
  }
}

