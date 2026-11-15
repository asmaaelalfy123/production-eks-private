###############################################################################
# VPC — using terraform-aws-modules/vpc/aws
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}


###############################################################################
# EKS — using terraform-aws-modules/eks/aws
###############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Private-only API endpoint
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Grant the cluster creator (your IAM user) admin access
  enable_cluster_creator_admin_permissions = true

  # Managed node group
  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }
}

###############################################################################
# Allow VPN server to reach the EKS API on port 443
###############################################################################
resource "aws_security_group_rule" "vpn_to_eks_api" {
  description              = "Allow VPN server to access EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.vpn.id
}

###############################################################################
# OpenVPN Server on EC2
###############################################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "vpn" {
  name_prefix = "${var.project_name}-vpn-"
  vpc_id      = module.vpc.vpc_id
  description = "OpenVPN server security group"

  ingress {
    description = "OpenVPN"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-vpn-sg"
  }
}

resource "aws_instance" "vpn" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.openvpn_instance_type
  key_name                    = var.ssh_key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  associate_public_ip_address = true
  source_dest_check           = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/openvpn_userdata.sh", {
    vpc_cidr        = var.vpc_cidr
    vpn_client_cidr = var.vpn_client_cidr
  })

  tags = {
    Name = "${var.project_name}-openvpn"
  }
}

resource "aws_eip" "vpn" {
  instance = aws_instance.vpn.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-vpn-eip"
  }
}
