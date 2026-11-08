# Bootstrap GitOps : Terraform installe Argo CD puis l'application racine (app-of-apps).
# Tout le reste de la plateforme est ensuite piloté par Git.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  wait             = true
  timeout          = 600

  values = [yamlencode({
    configs = { params = { "server.insecure" = true } }
    dex     = { enabled = false }
  })]
}

resource "helm_release" "root_app" {
  name       = "root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "^2.0.0"

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.repo_url
          targetRevision = var.git_revision
          path           = "apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
