locals {
  k8s_subnets = cidrsubnets(local.ipv6_k8s_prefix,
    /* loadbalancer */ 32,
    /* apiserver */ 32,
    /* pod */ 16,
  )

  # kube-apiserver
  k8s_service_ipv4 = element(sakura_internet.internet.ip_addresses, -1)
  k8s_service_ipv6 = cidrhost(local.k8s_subnets[1], parseint("1008", 16)) # k8?

  # LoadBalancer service
  k8s_lb_ipv4_start  = element(sakura_internet.internet.ip_addresses, -1 - 2 + 1)
  k8s_lb_ipv4_end    = element(sakura_internet.internet.ip_addresses, -2)
  k8s_lb_ipv6_subnet = local.k8s_subnets[0]

  k8s_pod_cidr     = "${cidrhost(local.k8s_subnets[2], 0)}/108"
  k8s_service_cidr = "fd01::/108"

  ansible_inventory = {
    "_meta" = {
      hostvars = merge({
        nat64box = {
          ansible_host = cidrhost(local.ipv6_nat64box_prefix, 1),
        } },
        { for i in range(var.cplane_nodes) : "cplane-${i}" => {
          ansible_host = cidrhost(local.ipv6_cplane_prefix, i)
        } },
        { for i in range(var.worker_nodes) : "worker-${i}" => {
          ansible_host = cidrhost(local.ipv6_worker_prefix, i)
      } })
    }

    all = {
      vars = {
        ansible_user       = "ictsc"
        nat64_prefix       = "64:ff9b::"
        cplane_ipv6_subnet = local.ipv6_cplane_prefix
        worker_ipv6_subnet = local.ipv6_worker_prefix
      }
    }
    nat64box = {
      hosts = ["nat64box"]
    }

    kubernetes = {
      vars = {
        k8s_service_ipv4   = local.k8s_service_ipv4
        k8s_service_ipv6   = local.k8s_service_ipv6
        k8s_service_cidr   = local.k8s_service_cidr
        k8s_pod_cidr       = local.k8s_pod_cidr
        k8s_lb_ipv4_start  = local.k8s_lb_ipv4_start
        k8s_lb_ipv4_end    = local.k8s_lb_ipv4_end
        k8s_lb_ipv6_subnet = local.k8s_lb_ipv6_subnet
      }
      children = ["bootstrap", "cplane", "worker"]
    }
    bootstrap = { hosts = ["cplane-0"] }
    cplane = {
      hosts = [for i in range(var.cplane_nodes) : "cplane-${i}"]
    }
    worker = {
      hosts = [for i in range(var.worker_nodes) : "worker-${i}"]
    }
  }
}

output "ansible_inventory" {
  value = jsonencode(local.ansible_inventory)
}
