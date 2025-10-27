locals {
  ansible_inventory = {
    "_meta" = {
      hostvars = merge(
        {
          nat64box = {
            ansible_host = var.nat64box_host.address
            ansible_user = var.nat64box_host.user
          }
        },
        {
          for i, node in var.cplane_hosts : "cplane-${i}" => {
            ansible_host = node.address
            ansible_user = node.user
          }
        },
        {
          for i, node in var.worker_hosts : "worker-${i}" => {
            ansible_host = node.address
            ansible_user = node.user
          }
        }
      )
    }

    all = {
      vars = {
        vault_id         = var.vault_id
        nat64_prefix     = var.nat64_prefix
        cplane_ipv6_cidr = var.cplane_ipv6_cidr
        worker_ipv6_cidr = var.worker_ipv6_cidr
        proxy_ipv4_addrs = flatten([
          [var.k8s_api_ipv4], var.k8s_lb_ipv4_addrs
        ])
      }
    }
    nat64box = {
      hosts = ["nat64box"]
    }

    kubernetes = {
      vars = {
        k8s_cluster_name  = var.k8s_cluster_name
        k8s_api_host      = var.k8s_api_host
        k8s_api_ipv4      = var.k8s_api_ipv4
        k8s_api_ipv6      = var.k8s_api_ipv6
        k8s_service_cidr  = var.k8s_service_cidr
        k8s_pod_cidr      = var.k8s_pod_cidr
        k8s_lb_ipv4_addrs = var.k8s_lb_ipv4_addrs
        k8s_lb_ipv6_cidr  = var.k8s_lb_ipv6_cidr
      }
      children = ["bootstrap", "cplane", "worker"]
    }
    bootstrap = { hosts = ["cplane-0"] }
    cplane = {
      hosts = [for i in range(length(var.cplane_hosts)) : "cplane-${i}"]
    }
    worker = {
      hosts = [for i in range(length(var.worker_hosts)) : "worker-${i}"]
    }
  }
}
