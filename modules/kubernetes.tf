provider "kubernetes" {
  host                   = aws_eks_cluster.example.endpoint
  token                  = data.aws_eks_cluster_auth.example.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.example.certificate_authority[0].data)
}

data "aws_eks_cluster_auth" "example" {
  name = aws_eks_cluster.example.name
}

resource "kubernetes_cluster_role" "example" {
  metadata {
    name = "example-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "example-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.example.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "example-service-account"
    namespace = "default"
  }
}
