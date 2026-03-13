output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS private API endpoint"
  value       = module.eks.cluster_endpoint
}

output "openvpn_public_ip" {
  value = aws_eip.vpn.public_ip
}

output "ssh_to_vpn" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_eip.vpn.public_ip}"
}

output "configure_kubectl" {
  description = "Run after connecting to VPN"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "grafana_url" {
  description = "Grafana URL (accessible only through VPN)"
  value       = "http://grafana.devops.private"
}

output "grafana_lb_hostname" {
  description = "Grafana internal load balancer hostname"
  value       = data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname
}

output "route53_private_zone_id" {
  value = aws_route53_zone.private.zone_id
}

