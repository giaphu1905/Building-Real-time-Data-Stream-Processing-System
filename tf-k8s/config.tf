resource "kubernetes_namespace" "pipeline-namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_namespace" "spark-operator" {
  metadata {
    name = "spark-operator"
    labels = {
      "app" = "spark-operator"
    }
  }
}

resource "kubernetes_namespace" "grafana-namespace" {
  metadata {
    name = "grafana"
  }
}

resource "kubernetes_config_map" "pipeline-config" {
  metadata {
    name      = "pipeline-config"
    namespace = var.namespace
  }

  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]

  data = {
    FINNHUB_STOCKS_TICKERS        = jsonencode(var.finnhub_stocks_tickers)
    FINNHUB_VALIDATE_TICKERS      = "1"
    
    KAFKA_SERVER                  = "kafka-service.${var.namespace}.svc.cluster.local"
    KAFKA_PORT                    = "9092"
    KAFKA_TOPIC_NAME              = "crypto-market"
    KAFKA_MIN_PARTITIONS          = "1"
    
    SPARK_MASTER                  = "spark://spark-master:7077"
    SPARK_MAX_OFFSETS_PER_TRIGGER = "100"    #depend on min_partitions and volume of data, many tests to find the best value
    SPARK_SHUFFLE_PARTITIONS      = "8"      #tuning performance of my laptop (8 cores)
    SPARK_DEPRECATED_OFFSETS      = "False"

    CASSANDRA_HOST                = "cassandra.${var.namespace}.svc.cluster.local"
    CASSANDRA_PORT                = "9042"
    CASSANDRA_TABLE_TRADES        = "trades"
    CASSANDRA_TABLE_AGGREGATES    = "running_averages_15_sec"
    CASSANDRA_KEYSPACE            = "crypto_market_ksp"
  }
}

########################cassandra_config_map########################
resource "kubernetes_config_map" "cassandra_setup_keyspace_tables" {
    metadata {
        name = "create-keyspace-tables"
        namespace = var.namespace
    }
    depends_on = [ kubernetes_namespace.pipeline-namespace ]
    data = {
        "cassandra-setup.cql" = file("cassandra_setup_cql/cassandra-setup.cql")
    }
}

########################grafana_config_map########################
resource "kubernetes_config_map" "grafana-dashboard-pipeline" {
  metadata {
    name      = "grafana-dashboard-pipeline"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "dashboard_pipeline.json" = file("./grafana_setup_dashboard/dashboards/dashboard_pipeline.json")
  }
}
resource "kubernetes_config_map" "grafana-provisioning-datasources" {
  metadata {
    name      = "grafana-provisioning-datasources"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
  }
  data = {
    "cassandra.yaml" = file("grafana_setup_dashboard/provisioning/datasources/cassandra.yaml")
  }
}
resource "kubernetes_config_map" "grafana-provisioning-dashboards" {
  metadata {
    name      = "grafana-provisioning-dashboards"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
  }
  data = {
    "dashboard.yaml" = file("grafana_setup_dashboard/provisioning/dashboards/dashboard.yaml")
  }
}

resource "kubernetes_network_policy" "pipeline-network" {
  metadata {
    name = "pipeline-network"
    namespace = var.namespace
  }
  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]

  spec {
    pod_selector {
      match_labels = {
        pipeline-network = "true"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            pipeline-network = "true"
          }
        }
      }
    }
  }
}