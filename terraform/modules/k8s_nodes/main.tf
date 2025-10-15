terraform {
  required_providers {
    sakura = {
      source  = "sacloud/sakura"
      version = "3.0.0-beta2"
    }
  }
}

locals {
  required_ip_count          = var.cplane_nodes + var.worker_nodes + 1 + 1
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

data "sakura_archive" "debian" {
  tags = ["cloud-init", "distro-debian", "distro-ver-12.7.0"]
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

  ipv6_nat64box_prefix = local.ipv6_subnets[1]
  ipv6_cplane_prefix   = local.ipv6_subnets[2]
  ipv6_worker_prefix   = local.ipv6_subnets[3]
  ipv6_k8s_prefix      = local.ipv6_subnets[4]
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
    ip6_addr    = cidrhost(local.ipv6_nat64box_prefix, 1)
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
    ssh_key     = data.sakura_ssh_key.ictsc.public_key
    ip6_addr    = cidrhost(local.ipv6_cplane_prefix, count.index)
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
    ssh_key     = data.sakura_ssh_key.ictsc.public_key
    ip6_addr    = cidrhost(local.ipv6_worker_prefix, count.index)
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
#
# resource "sakura_server" "worker" {
#   count  = var.worker_nodes
#   tags   = var.tags
#   name   = "k8s-${var.env}-worker-${count.index}"
#   core   = 2
#   memory = 4
#
#   disks = [
#     sakura_disk.worker_root[count.index].id,
#     sakura_disk.worker_data[count.index].id,
#   ]
#   network_interface = [{
#     upstream        = sakura_internet.internet.switch_id
#     user_ip_address = sakura_internet.internet.ip_addresses[local.worker_ip_base + count.index]
#   }]
#
#   user_data = templatefile("${path.module}/cloud-init-worker.yaml.tftpl", {
#     password_hash = var.password_hash
#     ssh_keys      = [data.sakura_ssh_key.ictsc.public_key]
#     ip4_addr      = "${sakura_internet.internet.ip_addresses[local.worker_ip_base + count.index]}/${sakura_internet.internet.netmask}"
#     ip6_addr      = "${local.ipv6_node_prefix}${sakura_internet.internet.ip_addresses[local.worker_ip_base + count.index]}/64"
#   })
#
#   lifecycle {
#     replace_triggered_by = [sakura_disk.worker_root[count.index].id]
#   }
# }
#
# resource "sakura_disk" "worker_root" {
#   count             = var.worker_nodes
#   tags              = var.tags
#   name              = "k8s-${var.env}-worker-${count.index}-root"
#   description       = "k8s worker root disk"
#   plan              = "ssd"
#   size              = 20
#   source_archive_id = data.sakura_archive.debian.id
# }

resource "sakura_disk" "worker_data" {
  count       = var.worker_nodes
  tags        = var.tags
  name        = "k8s-${var.env}-worker-${count.index}-data"
  description = "k8s worker data disk"
  plan        = "ssd"
  size        = 40
}
