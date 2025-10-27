# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project Overview

**ictsc-k8s-infra** is a Kubernetes infrastructure project for ICTSC. It manages a k0s Kubernetes cluster on Sakura Cloud with IPv4/IPv6 dual-stack networking, NAT64 support, Cilium CNI, and observability via OpenTelemetry Collector.

## Technology Stack

- **Infrastructure as Code**: Terraform (Sakura Cloud provider, S3 backend on isk01.sakurastorage.jp)
- **Kubernetes**: k0s lightweight distribution with Cilium CNI
- **Configuration Management**: Ansible (v10+) with uv for Python package management
- **Manifest Management**: Kustomize (v5+) with Helm Chart integration
- **CLI Tools**: aqua for declarative version management (tenv, uv, usacloud, kustomize, etc.)
- **Networking**: IPv4/IPv6 dual-stack, NAT64 prefix translation, Cilium Gateway API
- **Observability**: OpenTelemetry Collector, Hubble UI for Cilium visibility

## Common Development Commands

### Terraform Operations
```bash
# Initialize Terraform (requires S3 backend credentials via environment)
make tf-init

# Plan infrastructure changes
make tf-plan

# Apply infrastructure changes
make tf-apply

# Format and validate Terraform code
make tf-fmt
make tf-validate
make validate  # Runs both tf-validate and ansible-validate
```

### Ansible Operations
```bash
# Generate Kubernetes manifests and run Ansible playbook
make ansible-apply

# Validate Ansible playbooks
make ansible-validate
```

### Kubernetes Manifest Generation
```bash
# Generate all Kustomize manifests (creates manifests/*/dev.generated.yaml)
make manifests

# Clean generated manifests
make clean-manifests
```

## Architecture and Key Concepts

### Infrastructure Architecture
The Terraform module in `terraform/modules/k8s_nodes/` (`terraform/env/dev/main.tf`) provisions:
- **NAT64 Box**: Single node handling IPv6-to-IPv4 translation
- **Control Plane**: Configurable number of nodes (default: 3) running k0s API server
- **Worker Nodes**: Configurable number of nodes (default: 3) for workload scheduling
- **Load Balancer**: Multiple IPv4 addresses for service ingress (default: 4)
- **Network**: IPv6 subnets allocated via CIDR subnetting for different node groups

**Key Terraform Outputs** (`terraform/env/dev/main.tf`):
- `ansible_inventory`: Dynamic inventory for Ansible provisioning
- `k8s_api_host`, `k8s_api_ipv4`, `k8s_api_ipv6`: Kubernetes API access endpoints
- `web_ipv4`, `web_ipv6`: Load balancer endpoint addresses

### Ansible Playbook Structure
`ansible/setup.yaml` orchestrates cluster setup in stages:

1. **OpenTelemetry Setup** (all hosts): Installs metrics collection agent
2. **NAT64 Configuration** (nat64box group): Sets up IPv6-to-IPv4 translation
3. **k0s Installation** (kubernetes group): Installs k0s binaries
4. **Control Plane Config** (cplane group): Firewall rules, k0s cluster configuration
5. **Bootstrap First Controller** (cplane:&bootstrap): Initializes the cluster
6. **Join Additional Controllers** (cplane:!bootstrap): High availability setup
7. **Join Workers** (worker group): Registers worker nodes to cluster

### Role Organization
Key Ansible roles in `ansible/roles/`:
- `install_k0s/`: Downloads and installs k0s binaries
- `k0s/`: Generates and applies k0s cluster configuration
- `bootstrap_controller/`: Initializes the first control plane node
- `join_controller/`, `join_worker/`: Node joining automation
- `cplane_firewall/`: Control plane network policies
- `otelcol/`: OpenTelemetry Collector daemon setup
- `nat64box/`: NAT64 box configuration
- `backup_k0s/`: k0s state backup functionality
- `reset_k0s/`: Cluster reset automation

### Kubernetes Manifest Management
Manifests use Kustomize with base and overlay pattern:
```
manifests/
├── cilium/
│   ├── base/           # Cilium Helm Chart base
│   └── dev/            # Development overlay with kustomization.yaml
├── coredns/
└── rbac/
```

Generated manifests are created at `manifests/*/dev.generated.yaml` via `kustomize build --enable-helm` and applied during `make ansible-apply`.

## Environment Variables

The following environment variables are used by the infrastructure:

**Terraform** (`terraform/env/dev/main.tf`):
- `AWS_REQUEST_CHECKSUM_CALCULATION`: S3 backend configuration (set to `when_required` in Makefile)

**Ansible** (`ansible/setup.yaml`):
- `SAKURACLOUD_METRICS_ENDPOINT`: OpenTelemetry metrics ingestion endpoint
- `SAKURACLOUD_METRICS_TOKEN`: OpenTelemetry authentication token
- `SAKURACLOUD_S3_BACKUP_ACCESS_KEY_ID`: S3 backup access key
- `SAKURACLOUD_S3_BACKUP_SECRET_ACCESS_KEY`: S3 backup secret key

These environment variables must be set before running infrastructure commands.

## Important Notes for Development

1. **Terraform State**: Uses S3 backend on Sakura Storage (`terraform/env/dev/main.tf:9-20`). Requires S3 credentials in environment.

2. **Ansible Inventory**: Generated dynamically from Terraform outputs. The `ansible_inventory` output provides the inventory file.

3. **Manifest Generation Required**: Run `make manifests` before `make ansible-apply` to ensure manifests are current.

4. **k0s Configuration**: Cluster configuration is templated and applied to control plane nodes via `k0s` role. Configuration changes require re-running Ansible.

5. **Control Plane HA**: Multiple control plane nodes provide high availability. Bootstrap initializes the first, additional nodes join via `join_controller` role.

6. **Gateway API**: Uses Cilium Gateway API (`gateway.yaml`) for advanced routing.

7. **Cluster Reset**: `ansible/reset_k0s.yaml` playbook can reset the cluster. Use with caution.

8. **Git Commits**: Always verify staged files before committing:
   - Do NOT use `git add -A` (includes untracked files)
   - Run `git status` and `git diff --cached` to verify what will be committed
   - Only commit explicitly staged files
   - Use `git restore --staged <file>` to unstage unwanted files

## File Organization Summary

- **`terraform/env/dev/`**: Environment-specific Terraform entry point
- **`terraform/modules/k8s_nodes/`**: Reusable infrastructure module for cluster provisioning
- **`ansible/`**: Cluster setup automation (roles, playbooks, Python dependencies via uv)
- **`manifests/`**: Kubernetes resources (Cilium, CoreDNS, RBAC) using Kustomize
- **`Makefile`**: Command wrappers for Terraform, Ansible, and Kustomize operations
- **`aqua.yaml`**: Declarative tool version management

## Customization Points

- **Environment**: Default is `dev`. Override with `ENV=<name> make tf-plan` for different environments.
- **Node Counts**: Configure `cplane_nodes` and `worker_nodes` in `terraform/env/dev/main.tf`.
- **Network CIDR**: Modify variables passed to `k8s_nodes` module.
- **Cilium Configuration**: Edit `manifests/cilium/dev/kustomization.yaml` to customize Helm values.
- **Manifest Generation**: Build manifests using `make manifests` to generate the required manifest files.