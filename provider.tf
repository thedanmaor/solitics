terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.35.0"
    }
    k8s = {
      source  = "banzaicloud/k8s"
      version = "~> 0.9.1"
    }
  }
}
