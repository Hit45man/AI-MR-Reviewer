# Platform namespace + IRSA ServiceAccounts (apps in gitops reference these names)
resource "kubernetes_namespace_v1" "platform" {
  metadata {
    name = "platform"
    labels = {
      "app.kubernetes.io/part-of" = "aws-mr-reviewer"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_account_v1" "litellm" {
  metadata {
    name      = "litellm"
    namespace = kubernetes_namespace_v1.platform.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.eks.litellm_role_arn
    }
  }
}

resource "kubernetes_service_account_v1" "mr_reviewer" {
  metadata {
    name      = "mr-reviewer"
    namespace = kubernetes_namespace_v1.platform.metadata[0].name
  }
}

# AWS Load Balancer Controller
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.lbc_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  depends_on = [module.eks]
}

# Argo CD + root Application (Application CR created by the chart — avoids CRD plan race)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.7.18"

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
      applications = {
        aws-mr-reviewer = {
          namespace = "argocd"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io",
          ]
          project = "default"
          source = {
            repoURL        = var.git_repo_url
            targetRevision = var.git_repo_revision
            path           = "gitops"
            directory = {
              recurse = true
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "platform"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true",
            ]
          }
        }
      }
    }),
  ]

  depends_on = [module.eks, helm_release.aws_lbc]
}
