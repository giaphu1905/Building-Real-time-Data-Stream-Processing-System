# resource "kubernetes_namespace" "trino" {
#     metadata {
#         name = "trino"
#     }
# }
# resource "helm_release" "trino" {
#     name       = "trino"
#     namespace  = kubernetes_namespace.trino.metadata.0.name
#     chart      = "trino"
#     repository = "https://trinodb.github.io/charts/"
#     depends_on = [ 
#         kubernetes_stateful_set.cassandra,
#         kubernetes_namespace.trino,
#     ]
#     set {
#         name  = "additionalConfig.cassandra.properties"
#         value = <<-EOT
#             connector.name=cassandra
#             cassandra.contact-points=cassandra.${var.namespace}.svc.cluster.local
#             cassandra.load-policy.dc-aware.local-dc=DataCenter1
#             EOT
#         }
#     set {
#         name  = "http-server.authentication.type"
#         value = "BASIC"
#     }

#     set {
#         name  = "discovery.uri"
#         value = "http://trino.pipeline.svc.cluster.local:8080"
#     } 
#     set {
#         name  = "worker.count"
#         value = "1"
#     }
#     set {
#         name  = "worker.resources.limits.memory"
#         value = "500m"
#     }
# }
