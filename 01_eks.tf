data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "aws_kms_key" "eks" {
  description = "${local.cluster_name}-eks-secrets-key"
  tags        = local.tags
}

module "eks" {
  source          = "github.com/terraform-aws-modules/terraform-aws-eks"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id

  subnet_ids = merge(
    module.vpc.public_subnets,
    module.vpc.private_subnets,
  )

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  eks_managed_node_group_defaults = {
    subnets = merge(
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

  tags = local.tags
}
