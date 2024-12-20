terraform {
  required_version = ">= 0.13.1"

  required_providers {
    #aws = {
    #  source  = "hashicorp/aws"
    #  version = ">= 4.57"
    #}
  }
}

provider "kubernetes" {
  config_path    = var.kube_config  
  config_context = "docker-desktop"  
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config
  }
}