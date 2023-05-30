terraform {
  # backend "s3" {
  #   bucket = ""
  #   key    = ""
  #   region = ""
  # }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
    time = {
      source = "hashicorp/time"
    }
    rancher2 = {
      source = "rancher/rancher2"
    }
  }
  required_version = ">= 0.13"
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  ignore_annotations = [
    # Ignore *.cattle.io/* annotations, they are populated by Rancher
    ".*\\.?cattle\\.io\\/.*",
  ]
}