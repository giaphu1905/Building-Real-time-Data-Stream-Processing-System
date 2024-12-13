resource "kubernetes_stateful_set" "cassandra" {
    metadata {
        name      = "cassandra"
        namespace = var.namespace
    }

    depends_on = [
        kubernetes_persistent_volume_claim.cassandra-db-volume,
        kubernetes_persistent_volume.cassandra-db-volume,
        kubernetes_config_map.cassandra_setup_keyspace_tables
    ] 

    spec {
        service_name = "cassandra"
        replicas     = 1

        selector {
            match_labels = {
                app = "cassandra"
            }
        }

        template {
            metadata {
                labels = {
                    pipeline-network = "true"
                    app = "cassandra"
                }
            }

            spec {
                hostname = "cassandra"

                volume {
                    name = "cassandra-data"
                    persistent_volume_claim {
                        claim_name = "cassandra-db-volume"
                    }
                }

                volume {
                    name = "cassandra-setup-volume"
                    config_map {
                        name = kubernetes_config_map.cassandra_setup_keyspace_tables.metadata[0].name
                    }
                }

                container {
                    name  = "cassandra"
                    image = "cassandra:4.0.15"
                    lifecycle {
                        post_start {
                            exec {
                                command = [
                                    "/bin/bash",
                                    "-c",
                                    "until cqlsh -e 'DESCRIBE KEYSPACES'; do sleep 6; done; cqlsh -f /setup/cassandra-setup.cql; echo 'Cassandra setup completed';"
                                ]
                            }
                        }
                    }
      
                    port {
                        name           = "cql"
                        container_port = 9042
                    }
                    volume_mount {
                        name       = "cassandra-setup-volume"
                        mount_path = "/setup"
                    }

                    volume_mount {
                        name      = "cassandra-data"
                        mount_path = "/var/lib/cassandra"
                    }

                    env {
                        name  = "CASSANDRA_CLUSTER_NAME"
                        value = "CassandraCluster"
                    }

                    env {
                        name  = "CASSANDRA_DATACENTER"
                        value = "DataCenter1"
                    }

                    env {
                        name  = "CASSANDRA_RACK"
                        value = "Rack1"
                    }

                    env {
                        name  = "CASSANDRA_ENDPOINT_SNITCH"
                        value = "GossipingPropertyFileSnitch" #Phù hợp với Kubernetes
                    }

                    env {
                        name  = "CASSANDRA_HOST"
                        value = "cassandra.${var.namespace}.svc.cluster.local:9042"
                    }

                    env {
                        name  = "CASSANDRA_NUM_TOKENS"
                        value = "128"
                    }

                    env {
                        name = "CASSANDRA_USER"
                        value_from {
                            secret_key_ref {
                                name = "pipeline-secrets"
                                key  = "CASSANDRA_USER"
                            }
                        }   
                    }

                    env {
                        name = "CASSANDRA_PASSWORD"
                        value_from {
                            secret_key_ref {
                                name = "pipeline-secrets"
                                key  = "CASSANDRA_PASSWORD"
                            }
                        }
                    }      

                    env {
                        name  = "HEAP_NEWSIZE"  # size of the young generation
                        value = "128M"
                    }

                    env {
                        name  = "MAX_HEAP_SIZE"
                        value = "256M"
                    }

                    env {
                        name = "POD_IP"
                        value_from {
                            field_ref {
                                field_path = "status.podIP"
                            }
                        }
                    }          
                }
            }
        }
    }
}

resource "kubernetes_service" "cassandra" {
    metadata {
        name      = "cassandra"
        namespace = var.namespace
        labels = {
            app = "cassandra"
        }
    }
    depends_on = [
        kubernetes_stateful_set.cassandra
    ]
    spec {
        selector = {
            app = "cassandra"
        }

        port {
            name       = "cql"
            port       = 9042
            target_port = 9042
        }
        cluster_ip = "None"
    }
}

resource "kubernetes_deployment" "cassandra_web" {
  metadata {
    name = "cassandra-web"
    namespace = var.namespace
    labels = {
      app = "cassandra-web"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "cassandra-web"
      }
    }
    template {
      metadata {
        labels = {
          app = "cassandra-web"
        }
      }
      spec {
        container {
          image = "ipushc/cassandra-web:v1.1.5"
          name  = "cassandra-web"
          port {
            container_port = 8083
          }
          env {
            name  = "CASSANDRA_HOST"
            value = "cassandra"
          }
          env {
            name  = "CASSANDRA_PORT"
            value = "9042"
          }
          env {
            name  = "CASSANDRA_USERNAME"
            value = "cassandra"
          }
          env {
            name  = "CASSANDRA_PASSWORD"
            value = "cassandra"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "cassandra_web" {
  metadata {
    name = "cassandra-web"
    namespace = var.namespace
  }
  depends_on = [ kubernetes_deployment.cassandra_web ]
  spec {
    selector = {
      app = "cassandra-web"
    }
    port {
      name        = "cassandra-web"
      port        = 8083
      target_port = "8083"
    }
    
  }
}