
resource "aws_kms_key" "eks" {
  description = "${local.cluster_name}-eks-secrets-key"
  tags        = local.tags
}

data "aws_caller_identity" "current" {}

module "eks" {
  source          = "github.com/terraform-aws-modules/terraform-aws-eks"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  subnet_ids = concat(
    module.vpc.public_subnets,
    module.vpc.private_subnets,
  )
  control_plane_subnet_ids = module.vpc.intra_subnets

  create_kms_key = false
  cluster_encryption_config = {
    resources = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Further extend node security group.
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    subnets = concat(
      module.vpc.public_subnets,
      module.vpc.private_subnets,
    )
    asg_max_size         = var.node_group_max_size
    asg_min_size         = var.node_group_min_size
    asg_desired_capacity = var.node_group_desired_capacity
    instance_type        = var.node_group_instance_type
  }

  eks_managed_node_groups = {
    main = {
      key_name = ""
    }
  }

  # An admin role always alows access to the cluster from AdministatorAccess SSO
  manage_aws_auth_configmap = true  # WARNING: The README says not to use this, but when I don't I get aws-auth does not exist errors
  aws_auth_roles = [
    {
      rolearn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*"
      username = "admin"
      groups = [
        "system:masters",
      ]
    }
  ]

  tags = local.tags
}
