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
  source                  = "../../modules/k8s_nodes"
  env                     = "dev"
  tags                    = ["k8s", "dev"]
  cplane_nodes            = 3
  worker_nodes            = 3
  loadbalancer_ipv4_count = 1
}

output "ansible_inventory" {
  value = module.k8s_nodes.ansible_inventory
}

output "k8s_api_host" {
  value = module.k8s_nodes.k8s_api_host
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
  value = cidrhost(module.k8s_nodes.k8s_lb_ipv6_subnet, parseint("80", 16))
}
