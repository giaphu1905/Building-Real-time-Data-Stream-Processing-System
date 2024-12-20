resource "kubernetes_service_account" "spark-service-account" {
  metadata {
    name      = "spark-sa"
    namespace = var.namespace
    labels = {
      "app" = "spark-operator"
    }
  }
  automount_service_account_token = true
  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]
}

resource "kubernetes_role" "spark-role" {
  metadata {
    name      = "spark-role"
    namespace = var.namespace
    labels = {
      "app" = "spark-operator"
    }
  }

  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["pods"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["deployments"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["configmaps"]
  }
}

resource "kubernetes_role_binding" "spark-role-binding" {
  metadata {
    name      = "spark-role-binding"
    namespace = var.namespace
    labels = {
      "app" = "spark-operator"
    }
  }

  depends_on = [
    kubernetes_namespace.pipeline-namespace
  ]

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.spark-service-account.metadata[0].name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.spark-role.metadata[0].name
  }
}

resource "helm_release" "spark-operator" {
  name       = "spark-operator"
  repository = "https://kubeflow.github.io/spark-operator"
  chart      = "spark-operator"
  namespace  = "spark-operator"
  version     = "2.1.0"
  create_namespace = true
  depends_on = [ 
    kubernetes_namespace.spark-operator,
  ]
  set {
    name  = "spark.jobNamespaces"
    value = "{${var.namespace}}"
  }
}

# resource "kubernetes_manifest" "spark-operator-crds" {
#   for_each = fileset("./spark_crds", "*.yaml") 
#   manifest = yamldecode(file("./spark_crds/${each.value}"))
# }


