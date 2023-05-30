data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name            = "${local.cluster_name}-vpc"
  cidr            = "10.0.0.0/8"
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"] # 65534 addresses each
  public_subnets  = ["10.4.0.0/16", "10.5.0.0/16", "10.6.0.0/16"] # 65534 addresses each
  # For control plane
  intra_subnets = ["10.7.1.0/28", "10.7.1.16/28", "10.7.1.32/28"] # 15 addresses each
  # NAT Gateway will allow instances in private subnets to connect to the internet
  enable_nat_gateway = true
  # We will have a single, fixed, public IP for egress traffic, like on AKS
  # This will help when allowing connections to registries/artifactory.
  single_nat_gateway = true
  reuse_nat_ips      = true
  # Assign public DNS hostnames to instances with public IP addresses.
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })

  public_subnet_tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })

  private_subnet_tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# Allow SSH from our internal network
resource "aws_security_group" "allow_internal_ssh" {
  name_prefix = "${local.cluster_name}-allow_ssh"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  tags = local.tags
}