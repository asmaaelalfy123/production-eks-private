###############################################################################
# Route 53 Private Hosted Zone — devops.private
###############################################################################
resource "aws_route53_zone" "private" {
  name = "devops.private"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = {
    Name = "${var.project_name}-private-zone"
  }
}

###############################################################################
# Wait for Grafana LB to be ready, then get its hostname
###############################################################################
data "kubernetes_service" "grafana" {
  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = "monitoring"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

###############################################################################
# CNAME record: grafana.devops.private -> internal NLB hostname
###############################################################################
resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "grafana.devops.private"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname]
}
