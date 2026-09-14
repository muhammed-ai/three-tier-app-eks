# Dev Environment - Complete infrastructure for three-tier app

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    # Configure your S3 bucket for state storage
    # bucket         = "your-terraform-state-bucket"
    # key            = "dev/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "three-tier-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment            = var.environment
  cluster_name           = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  enable_nat_gateway    = var.enable_nat_gateway
  enable_flow_logs      = var.enable_flow_logs

  tags = var.tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name  = var.cluster_name
  environment   = var.environment
  subnet_ids    = module.vpc.private_subnet_ids
  cluster_version = var.cluster_version

  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs   = var.cluster_endpoint_public_access_cidrs

  node_groups = var.node_groups
  enable_irsa = true

  tags = var.tags
}

# EKS Addons Module
module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name        = var.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  install_aws_load_balancer_controller = true

  tags = var.tags
}

# RDS Module
resource "random_password" "db_password" {
  length  = 32
  special = false
}

module "rds" {
  source = "../../modules/rds"

  environment            = var.environment
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = random_password.db_password.result
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  allowed_security_groups = [module.eks.eks_cluster_security_group_id]
  allowed_cidr_blocks   = [module.vpc.vpc_cidr_block]
  instance_class         = var.db_instance_class
  multi_az               = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period

  tags = var.tags
}

# Store DB password in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}-db-credentials"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    host     = module.rds.db_endpoint
    port     = 3306
    database = var.db_name
    username = var.db_username
    password = random_password.db_password.result
  })
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "db_credentials_secret_arn" {
  description = "ARN of Secrets Manager secret with DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "configure_kubectl" {
  description = "kubectl configuration command"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
