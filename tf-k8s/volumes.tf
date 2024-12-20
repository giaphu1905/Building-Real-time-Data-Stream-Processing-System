resource "kubernetes_persistent_volume" "cassandra-db-volume" {
  metadata {
    name = "cassandra-db-volume"
  }
  spec {
    capacity = {
      storage = "15Gi"
    }
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "hostpath"
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/var/lib/minikube/pv0001/"
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim" "cassandra-db-volume" {
  metadata {
    name = "cassandra-db-volume"
    namespace = var.namespace
    labels = {
      app = "cassandra-db-volume"
    }
  }

  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "hostpath"

    resources {
      requests = {
        storage = "15Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume" "kafka-volume" {
  metadata {
    name = "kafka-volume"
  }
  depends_on = [
    kubernetes_persistent_volume_claim.cassandra-db-volume,
    kubernetes_persistent_volume.cassandra-db-volume
  ]
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "hostpath"
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/var/lib/minikube/pv0002/"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "kafka-volume" {
  metadata {
    name = "kafka-volume"
    namespace = var.namespace
    labels = {
      app = "kafka-volume"
    }
  }

  depends_on = [
    kubernetes_namespace.pipeline-namespace,
    kubernetes_persistent_volume_claim.cassandra-db-volume,
    kubernetes_persistent_volume.cassandra-db-volume
  ]

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "hostpath"

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume" "grafana-volume" {
  metadata {
    name = "grafana-volume"
  }

  spec {
    capacity = {
      storage = "1Gi"
    }

    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = "/var/lib/minikube/pv0003/"  # Chỉ định đường dẫn trên host nơi lưu trữ dữ liệu
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "grafana-volume" {
  metadata {
    name      = "grafana-volume"
    namespace = kubernetes_namespace.grafana-namespace.metadata[0].name
    labels = {
      app = "grafana-volume"
    }
  }
  depends_on = [ 
    kubernetes_persistent_volume.grafana-volume,
   ]
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "hostpath"
    resources {
      requests = {
        storage = "1Gi"
      }
    }

  }
}
