###############################################################################
# Namespace for monitoring
###############################################################################
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks]
}


###############################################################################
# kube-prometheus-stack (Prometheus + Grafana)
###############################################################################
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.0"

  # Grafana settings
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Expose Grafana via internal LoadBalancer (accessible through VPN)
  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-internal"
    value = "true"
    type  = "string"
  }

  set {
    name  = "grafana.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internal"
    type  = "string"
  }

  set {
    name  = "grafana.service.port"
    value = "80"
  }

  # Prometheus settings
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "20Gi"
  }

  depends_on = [module.eks]
}
