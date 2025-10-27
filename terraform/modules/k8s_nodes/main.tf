terraform {
  required_providers {
    sakura = {
      source  = "sacloud/sakura"
      version = "3.0.0-beta3"
    }
  }
}

locals {
  required_ip_count          = 1 /* nat64box */ + 1 /* k8s api */ + var.loadbalancer_ipv4_count
  internet_required_ip_count = local.required_ip_count + 5 # さくらのクラウドのルーター+スイッチは5IP分余計に必要
  internet_netmask           = min(28, 32 - ceil(log(local.internet_required_ip_count, 2)))
}

resource "sakura_internet" "internet" {
  tags        = var.tags
  name        = "k8s-${var.env}-internet"
  band_width  = 100
  netmask     = local.internet_netmask
  enable_ipv6 = true
}

data "sakura_ssh_key" "ictsc" {
  name = "ictsc2025"
}

locals {
  ipv6_subnets = cidrsubnets(sakura_internet.internet.ipv6_network_address,
    /* preserved(5) */ 32,
    /* nat64 */ 32,
    /* cplane */ 32,
    /* worker */ 32,
    /* k8s */ 16,
  )

  nat64box_ipv6_cidr = local.ipv6_subnets[1]
  cplane_ipv6_cidr   = local.ipv6_subnets[2]
  worker_ipv6_cidr   = local.ipv6_subnets[3]
  k8s_ipv6_cidr      = local.ipv6_subnets[4]
}

data "sakura_archive" "ubuntu" {
  tags = ["cloud-init", "distro-ubuntu", "distro-ver-24.04.2"]
}

resource "sakura_server" "nat64box" {
  tags   = flatten([var.tags, "nat64box"])
  name   = "k8s-${var.env}-nat64box"
  core   = 1
  memory = 1

  disks = [sakura_disk.nat64box.id]
  network_interface = [{
    upstream        = sakura_internet.internet.switch_id
    user_ip_address = sakura_internet.internet.ip_addresses[0]
  }]

  user_data = templatefile("${path.module}/cloud-init-nat64box.yaml", {
    ssh_key     = data.sakura_ssh_key.ictsc.public_key
    ip4_addr    = sakura_internet.internet.ip_addresses[0]
    ip4_mask    = sakura_internet.internet.netmask
    ip4_gateway = sakura_internet.internet.gateway
    ip6_addr    = cidrhost(local.nat64box_ipv6_cidr, 1)
  })

  lifecycle {
    replace_triggered_by = [sakura_disk.nat64box.id]
  }
}

resource "sakura_disk" "nat64box" {
  tags              = flatten([var.tags, "nat64box"])
  name              = "k8s-${var.env}-nat64box"
  description       = "k8s nat64box disk"
  plan              = "ssd"
  size              = 20
  source_archive_id = data.sakura_archive.ubuntu.id

  lifecycle {
    replace_triggered_by = [sakura_internet.internet.id]
  }
}

resource "sakura_server" "control_plane" {
  count  = var.cplane_nodes
  tags   = flatten([var.tags, "control-plane"])
  name   = "k8s-${var.env}-control-plane-${count.index}"
  core   = 1
  memory = 2

  disks = [sakura_disk.control_plane_root[count.index].id]
  network_interface = [{
    upstream = sakura_internet.internet.switch_id,
  }]

  user_data = templatefile("${path.module}/cloud-init-node.yaml", {
    user     = var.user
    ssh_key  = data.sakura_ssh_key.ictsc.public_key
    ip6_addr = cidrhost(local.cplane_ipv6_cidr, count.index)
  })

  lifecycle {
    replace_triggered_by = [sakura_disk.control_plane_root[count.index].id]
  }
}

resource "sakura_disk" "control_plane_root" {
  count             = var.cplane_nodes
  tags              = flatten([var.tags, "control-plane"])
  name              = "k8s-${var.env}-control-plane-${count.index}-root"
  description       = "k8s control plane root disk"
  plan              = "ssd"
  size              = 20
  source_archive_id = data.sakura_archive.ubuntu.id

  lifecycle {
    replace_triggered_by = [sakura_internet.internet.id]
  }
}

resource "sakura_server" "worker" {
  count  = var.worker_nodes
  tags   = flatten([var.tags, "worker"])
  name   = "k8s-${var.env}-worker-${count.index}"
  core   = 2
  memory = 4

  disks = [sakura_disk.worker_root[count.index].id]
  network_interface = [{
    upstream = sakura_internet.internet.switch_id,
  }]

  user_data = templatefile("${path.module}/cloud-init-node.yaml", {
    user     = var.user
    ssh_key  = data.sakura_ssh_key.ictsc.public_key
    ip6_addr = cidrhost(local.worker_ipv6_cidr, count.index)
  })

  lifecycle {
    replace_triggered_by = [sakura_disk.worker_root[count.index].id]
  }
}

resource "sakura_disk" "worker_root" {
  count             = var.worker_nodes
  tags              = flatten([var.tags, "worker"])
  name              = "k8s-${var.env}-worker-${count.index}-root"
  description       = "k8s worker root disk"
  plan              = "ssd"
  size              = 20
  source_archive_id = data.sakura_archive.ubuntu.id

  lifecycle {
    replace_triggered_by = [sakura_internet.internet.id]
  }
}

resource "sakura_disk" "worker_data" {
  count       = var.worker_nodes
  tags        = var.tags
  name        = "k8s-${var.env}-worker-${count.index}-data"
  description = "k8s worker data disk"
  plan        = "ssd"
  size        = 40
}
