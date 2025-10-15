variable "env" {
  description = "The environment for the Kubernetes nodes (e.g., dev, staging, prod)."
  type        = string
}

variable "tags" {
  description = "A list of tags to apply to the resources."
  type        = set(string)
  default     = []
}

variable "cplane_nodes" {
  description = "Number of control plane nodes."
  type        = number
  validation {
    condition     = var.cplane_nodes >= 1
    error_message = "There must be at least one control plane node."
  }
  validation {
    condition     = var.cplane_nodes % 2 == 1
    error_message = "The number of control plane nodes must be an odd number."
  }
}

variable "worker_nodes" {
  description = "Number of worker nodes."
  type        = number
  validation {
    condition     = var.worker_nodes >= 1
    error_message = "There must be at least one worker node."
  }
}

variable "loadbalancer_ipv4_count" {
  description = "Number of IPv4 addresses for the load balancer."
  type        = number
  default     = 1
}
