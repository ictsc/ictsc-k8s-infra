terraform {
  required_providers {
    sakura = {
      source  = "sacloud/sakura"
      version = "3.0.0-beta2"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://s3.isk01.sakurastorage.jp"
    }
    region                      = "jp-north-1"
    bucket                      = "ictsc-tfstates"
    key                         = "ictsc-k8s-dev.tfstate"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "sakura" {
  zone = "tk1b"
}

module "k8s_nodes" {
  source        = "../../modules/k8s_nodes"
  env           = "dev"
  tags          = ["k8s", "dev"]
  cplane_nodes  = 3
  worker_nodes  = 3
}

output "ansible_inventory" {
  value = module.k8s_nodes.ansible_inventory
}
