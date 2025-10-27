terraform {
  required_providers {
    sakura = {
      source  = "sacloud/sakura"
      version = "3.0.0-beta3"
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

locals {
  env              = "dev"
  k8s_cluster_name = "ictsc-${local.env}"
  k8s_api_host     = "k8s-${local.env}.ictsc.net"
}

module "k8s_nodes" {
  source                  = "../../modules/k8s_nodes"
  env                     = local.env
  tags                    = ["k8s", "dev"]
  cplane_nodes            = 3
  worker_nodes            = 3
  loadbalancer_ipv4_count = 4
}

data "sakura_kms" "ictsc_key" {
  name = "ictsc"
}

resource "sakura_secret_manager" "vault" {
  kms_key_id = data.sakura_kms.ictsc_key.id
  name       = "k8s-dev"
  tags       = ["k8s", "dev"]
}

module "ansible_inventory" {
  source = "../../modules/ansible_inventory"

  k8s_cluster_name  = local.k8s_cluster_name
  k8s_api_host      = local.k8s_api_host
  vault_id          = sakura_secret_manager.vault.id
  nat64box_host     = module.k8s_nodes.nat64box_host
  cplane_hosts      = module.k8s_nodes.cplane_hosts
  worker_hosts      = module.k8s_nodes.worker_hosts
  cplane_ipv6_cidr  = module.k8s_nodes.cplane_ipv6_cidr
  worker_ipv6_cidr  = module.k8s_nodes.worker_ipv6_cidr
  k8s_api_ipv4      = module.k8s_nodes.k8s_api_ipv4
  k8s_api_ipv6      = module.k8s_nodes.k8s_api_ipv6
  k8s_pod_cidr      = module.k8s_nodes.k8s_pod_cidr
  k8s_lb_ipv4_addrs = module.k8s_nodes.k8s_lb_ipv4_addrs
  k8s_lb_ipv6_cidr  = module.k8s_nodes.k8s_lb_ipv6_cidr
}

output "ansible_inventory" {
  value = module.ansible_inventory.ansible_inventory
}

output "k8s_api_host" {
  value = local.k8s_api_host
}

output "k8s_api_ipv4" {
  value = module.k8s_nodes.k8s_api_ipv4
}

output "k8s_api_ipv6" {
  value = module.k8s_nodes.k8s_api_ipv6
}

output "web_ipv4" {
  value = module.k8s_nodes.k8s_lb_ipv4_addrs[0]
}

output "web_ipv6" {
  value = cidrhost(module.k8s_nodes.k8s_lb_ipv6_cidr, parseint("80", 16))
}
