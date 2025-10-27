variable "vault_id" {
  description = "Sakura Cloud Secret Manager Vault ID."
  type        = string
}

variable "nat64box_host" {
  description = "NAT64 box host information."
  type = object({
    address = string
    user    = string
  })
}

variable "cplane_hosts" {
  description = "List of control plane host information."
  type = list(object({
    address = string
    user    = string
  }))
}

variable "worker_hosts" {
  description = "List of worker host information."
  type = list(object({
    address = string
    user    = string
  }))
}

variable "cplane_ipv6_cidr" {
  description = "IPv6 CIDR for the control plane nodes."
  type        = string
}

variable "worker_ipv6_cidr" {
  description = "IPv6 CIDR for the worker nodes."
  type        = string
}

variable "k8s_cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
}

variable "k8s_api_host" {
  description = "The hostname of the Kubernetes API server."
  type        = string
}

variable "k8s_api_ipv4" {
  description = "The IPv4 address of the Kubernetes API server."
  type        = string
}

variable "k8s_api_ipv6" {
  description = "The IPv6 address of the Kubernetes API server."
  type        = string
}

variable "k8s_service_cidr" {
  description = "The CIDR block for Kubernetes services."
  type        = string
  default     = "fd01::/108"
}

variable "k8s_pod_cidr" {
  description = "The CIDR block for Kubernetes pods."
  type        = string
}

variable "k8s_lb_ipv4_addrs" {
  description = "List of IPv4 addresses for Kubernetes LoadBalancer services."
  type        = list(string)
}

variable "k8s_lb_ipv6_cidr" {
  description = "The IPv6 CIDR for Kubernetes LoadBalancer services."
  type        = string
}

variable "nat64_prefix" {
  description = "The NAT64 prefix for IPv6 to IPv4 translation."
  type        = string
  default     = "64:ff9b::"
}
