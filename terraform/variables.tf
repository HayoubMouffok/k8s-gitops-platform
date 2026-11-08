variable "kubeconfig" {
  description = "Chemin du kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte Kubernetes cible"
  type        = string
  default     = "kind-gitops"
}

variable "repo_url" {
  description = "Dépôt Git suivi par Argo CD"
  type        = string
  default     = "https://github.com/HayoubMouffok/k8s-gitops-platform"
}

variable "git_revision" {
  description = "Branche, tag ou commit déployé"
  type        = string
  default     = "main"
}
