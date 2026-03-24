terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.17.0"
        }
        datadog = {
            source  = "DataDog/datadog"
            version = "~> 3.50"
        }
        helm = {
            source  = "hashicorp/helm"
            version = "~> 2.17"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = "~> 2.36"
        }
    }

    backend "s3" {
        bucket = "garage-terraform-state-211125475874"
        key    = "observability/terraform.tfstate"
        region = "us-east-1"
    }
}

locals {
    projectName = "garage"
    awsRegion   = "us-east-1"
    environment = var.environment
    clusterName = "${local.projectName}-cluster"
}

provider "aws" {
    region = local.awsRegion
}

data "aws_eks_cluster" "cluster" {
    name = local.clusterName
}

data "aws_eks_cluster_auth" "cluster" {
    name = local.clusterName
}

provider "kubernetes" {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
    kubernetes {
        host                   = data.aws_eks_cluster.cluster.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
        token                  = data.aws_eks_cluster_auth.cluster.token
    }
}

provider "datadog" {
    api_key = var.datadog_api_key
    app_key = var.datadog_app_key
    api_url = "https://us5.datadoghq.com/"
}
