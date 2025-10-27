locals {
  k8s_subnets = cidrsubnets(local.k8s_ipv6_cidr,
    /* loadbalancer */ 32,
    /* apiserver */ 32,
    /* pod */ 16,
  )

  # kube-apiserver
  k8s_api_ipv4 = element(sakura_internet.internet.ip_addresses, -1)
  k8s_api_ipv6 = cidrhost(local.k8s_subnets[1], parseint("1008", 16)) # k8?

  # LoadBalancer service
  k8s_lb_ipv4_addrs = [
    for i in range(var.loadbalancer_ipv4_count) :
    element(sakura_internet.internet.ip_addresses, -2 - i)
  ]
  k8s_lb_ipv6_cidr = local.k8s_subnets[0]

  k8s_pod_cidr     = "${cidrhost(local.k8s_subnets[2], 0)}/108"
}

output "nat64box_ipv6_cidr" {
  description = "IPv6 CIDR for the NAT64 box."
  value       = local.nat64box_ipv6_cidr
}

output "cplane_ipv6_cidr" {
  description = "IPv6 CIDR for the control plane nodes."
  value       = local.cplane_ipv6_cidr
}

output "worker_ipv6_cidr" {
  description = "IPv6 CIDR for the worker nodes."
  value       = local.worker_ipv6_cidr
}

output "nat64box_host" {
  description = "NAT64 box host information."
  value = {
    address = cidrhost(local.nat64box_ipv6_cidr, 1)
    user    = var.user
  }
}

output "cplane_hosts" {
  description = "List of control plane host information."
  value = [
    for i in range(var.cplane_nodes) : {
      address = cidrhost(local.cplane_ipv6_cidr, i)
      user    = var.user
    }
  ]
}

output "worker_hosts" {
  description = "List of worker host information."
  value = [
    for i in range(var.worker_nodes) : {
      address = cidrhost(local.worker_ipv6_cidr, i)
      user    = var.user
    }
  ]
}

output "k8s_api_ipv4" {
  description = "Kubernetes API server IPv4 address."
  value       = local.k8s_api_ipv4
}

output "k8s_api_ipv6" {
  description = "Kubernetes API server IPv6 address."
  value       = local.k8s_api_ipv6
}

output "k8s_pod_cidr" {
  description = "Kubernetes pod CIDR."
  value       = local.k8s_pod_cidr
}

output "k8s_lb_ipv4_addrs" {
  description = "Kubernetes LoadBalancer service IPv4 addresses."
  value       = local.k8s_lb_ipv4_addrs
}

output "k8s_lb_ipv6_cidr" {
  description = "Kubernetes LoadBalancer service IPv6 CIDR."
  value       = local.k8s_lb_ipv6_cidr
}
