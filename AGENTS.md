# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project Overview

**ictsc-k8s-infra** is a production-ready Kubernetes infrastructure project for ICTSC. It manages k0s Kubernetes clusters (dev and prod) on Sakura Cloud with:
- **Networking**: IPv4/IPv6 dual-stack, NAT64 translation, Cilium CNI with Gateway API support
- **Application Deployment**: ArgoCD for GitOps-based continuous delivery
- **Storage**: TopoLVM CSI driver for local storage, CloudNativePG for PostgreSQL
- **Security**: cert-manager for certificate management, CSI Secrets Store for secret injection
- **Observability**: OpenTelemetry Collector for metrics, Hubble UI for Cilium network visibility
- **Infrastructure**: Terraform-managed infrastructure, Ansible-automated cluster setup

## Technology Stack

- **Infrastructure as Code**: Terraform v1.13.4 (Sakura Cloud provider v3.0.0-rc1, S3 backend)
- **Kubernetes**: k0s lightweight distribution with Cilium CNI
- **Configuration Management**: Ansible v10+ (ansible-core v2.17+) with uv for Python package management
- **Manifest Management**: Kustomize v5.8+ with Helm Chart integration
- **CLI Tools**: aqua for declarative version management
  - tenv (Terraform/OpenTofu manager), uv (Python), usacloud (Sakura Cloud CLI)
  - kustomize, gh (GitHub CLI), cosign (container signing), trivy (security scanning)
- **Networking**:
  - Cilium CNI with Gateway API, Envoy Gateway
  - IPv4/IPv6 dual-stack with NAT64 prefix translation
  - L2 announcement for LoadBalancer services
- **Storage**: TopoLVM CSI driver (local storage), CloudNativePG operator (PostgreSQL)
- **Security**: cert-manager (TLS certificates), CSI Secrets Store, Sakura Cloud Secret Manager
- **GitOps**: ArgoCD for continuous delivery
- **Observability**: OpenTelemetry Collector, Hubble UI, telemetry stack

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
# Generate Kubernetes manifests and run Ansible playbook (default: dev environment)
make ansible-apply

# Run Ansible playbook for a specific environment
ENV=staging make ansible-apply
ENV=prod make ansible-apply

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
The infrastructure is managed via Terraform with two environments (dev/prod). The `k8s_nodes` module (`terraform/modules/k8s_nodes/`) provisions:
- **NAT64 Box**: Single node handling IPv6-to-IPv4 translation
- **Control Plane**: Configurable number of nodes (default: 3, must be odd) running k0s API server
- **Worker Nodes**: Configurable number of nodes (default: 3) for workload scheduling
- **Load Balancer**: Multiple IPv4 addresses for service ingress (default: 4)
- **Network**: IPv6 subnets allocated via CIDR subnetting for NAT64 box, control plane, and worker groups

**Terraform Modules:**
- `k8s_nodes`: Provisions Sakura Cloud infrastructure (servers, networks, load balancers)
- `ansible_inventory`: Generates dynamic Ansible inventory from infrastructure outputs

**Environment-Specific Configuration** (`terraform/env/{dev,prod}/main.tf`):
- Separate S3 backend state files per environment
- Environment-specific cluster names (ictsc-dev, ictsc-prod)
- Environment-specific API hostnames (k8s-dev.ictsc.net, k8s-prod.ictsc.net)
- Environment-specific Secret Manager vault IDs

**Key Terraform Outputs**:
- `ansible_inventory`: Complete Ansible inventory with all hosts, groups, and variables
- `k8s_api_host`: Kubernetes API server hostname (e.g., k8s-dev.ictsc.net)
- `k8s_api_ipv4`, `k8s_api_ipv6`: Kubernetes API server IP addresses
- `web_ipv4`: First LoadBalancer IPv4 address (for web ingress)
- `web_ipv6`: LoadBalancer IPv6 address (calculated from CIDR)

### Ansible Playbook Structure
`ansible/setup.yaml` orchestrates cluster setup in stages:

1. **OpenTelemetry Setup** (all hosts): Installs metrics collection agent
2. **NAT64 Configuration** (nat64box group): Sets up IPv6-to-IPv4 translation
3. **k0s Installation** (kubernetes group): Installs k0s binaries
4. **Control Plane Config** (cplane group): Swap configuration, firewall rules, k0s cluster configuration
5. **Bootstrap First Controller** (cplane:&bootstrap): Initializes the cluster and sets up backup
6. **Join Additional Controllers** (cplane:!bootstrap): High availability setup
7. **Setup Worker Nodes** (worker group): Worker-specific system configuration
8. **Join Workers** (worker group): Registers worker nodes to cluster

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
- `setup_swap/`: Swap configuration for nodes
- `setup_worker/`: Worker node setup and configuration

### Kubernetes Manifest Management
Manifests use Kustomize with base and overlay pattern. The project has 14 manifest directories:

**Core Infrastructure:**
- `cilium/`: Cilium CNI with Helm Chart (base, dev, prod overlays)
- `cilium-extra/`: Additional Cilium configurations
- `coredns/`: CoreDNS configuration
- `rbac/`: RBAC policies

**Application Deployment:**
- `argocd-install/`: ArgoCD installation (with CRDs)
- `argocd-apps/`: ArgoCD application definitions
- `argocd-extra/`: Additional ArgoCD configurations

**Networking:**
- `gateway/`: Gateway API resources
- `envoy-gateway/`: Envoy Gateway configuration (with CRDs)

**Security & Secrets:**
- `cert-manager/`: Certificate management (with CRDs)
- `csi-secrets-store/`: CSI Secrets Store driver (with CRDs)

**Storage & Database:**
- `topolvm/`: TopoLVM CSI driver (with CRDs)
- `cloudnative-pg/`: CloudNativePG operator (with CRDs)

**Observability:**
- `telemetry/`: OpenTelemetry and observability stack (with CRDs)

Each manifest directory follows the pattern:
```
manifests/<component>/
├── base/              # Base resources
├── crds/              # CRDs (if applicable)
├── components/        # Reusable components (if applicable)
├── dev/               # Development overlay
└── prod/              # Production overlay (if applicable)
```

Generated manifests are created via `kustomize build --enable-helm --load-restrictor LoadRestrictionsNone`:
- `manifests/*/crds.generated.yaml`: CRD definitions (where applicable)
- `manifests/*/dev.generated.yaml`: Development environment manifests
- `manifests/*/prod.generated.yaml`: Production environment manifests (where applicable)

Manifests are generated during `make manifests` and applied during `make ansible-apply`.

## Environment Variables and Secrets

### Environment Variables

The following environment variables are used by the infrastructure:

**Build Environment:**
- `ENV`: Target environment (default: `dev`, supports: `dev`, `prod`)
- `AWS_REQUEST_CHECKSUM_CALCULATION`: S3 backend configuration (set to `when_required` in Makefile)

### Secrets Management

The project uses **Sakura Cloud Secret Manager** for sensitive data via a custom Ansible lookup plugin (`ansible/plugins/lookup/sakura_secret.py`). Secrets are retrieved dynamically during playbook execution:

**Secrets stored in Sakura Secret Manager** (referenced in `ansible/setup.yaml`):
- `sakuracloud-metrics-endpoint`: OpenTelemetry metrics ingestion endpoint
- `sakuracloud-metrics-token`: OpenTelemetry authentication token
- `sakuracloud-secret-access-token`: Sakura Cloud access token
- `sakuracloud-secret-access-token-secret`: Sakura Cloud access token secret
- `sakuracloud-s3-backup-access-key-id`: S3 backup access key ID
- `sakuracloud-s3-backup-secret-access-key`: S3 backup secret access key

**Secret Manager Configuration:**
- Vault ID is passed via Terraform output (different for dev/prod)
- Secrets are environment-specific (managed via `env` variable)
- Access requires Sakura Cloud API credentials

No manual environment variable configuration is required for secrets; they are automatically retrieved from Secret Manager during Ansible execution.

## Important Notes for Development

1. **Dual Environment Setup**: The project supports both `dev` and `prod` environments
   - Each has separate Terraform state files and Secret Manager vaults
   - Default environment is `dev`; use `ENV=prod` for production operations
   - Ensure you're operating on the correct environment to avoid accidental changes

2. **Terraform State**: Uses S3 backend on Sakura Storage (endpoint: `s3.isk01.sakurastorage.jp`)
   - Separate state files: `ictsc-k8s-dev.tfstate` and `ictsc-k8s-prod.tfstate`
   - Backend configuration in `terraform/env/{dev,prod}/main.tf`
   - Requires S3-compatible credentials in environment

3. **Ansible Inventory**: Dynamically generated from Terraform outputs via `ansible/inventory.sh`
   - Reads from `terraform -chdir=../terraform/env/${ENV} output -raw ansible_inventory`
   - Includes all host groups, variables, and Sakura Secret Manager vault ID

4. **Manifest Generation**: Run `make manifests` before `make ansible-apply`
   - Generates CRDs and environment-specific manifests (dev/prod)
   - Uses `kustomize build --enable-helm --load-restrictor LoadRestrictionsNone`
   - Total of ~35 generated manifest files across 14 components

5. **Secret Management**: Secrets are stored in Sakura Cloud Secret Manager
   - Retrieved dynamically via custom lookup plugin (`ansible/plugins/lookup/sakura_secret.py`)
   - Environment-specific vaults (different vault IDs for dev/prod)
   - No need to set environment variables for secrets

6. **k0s Configuration**: Cluster configuration is templated and applied to control plane nodes
   - Configuration in `k0s` role with extensive variables
   - Changes require re-running Ansible playbook
   - Control plane node count must be odd (minimum 1, default 3)

7. **Control Plane HA**: Multi-node control plane for high availability
   - First controller bootstrapped with `bootstrap_controller` role
   - Additional controllers join via `join_controller` role
   - Backup configured via `backup_k0s` role

8. **GitOps with ArgoCD**: ArgoCD manages application deployments
   - Installation via `argocd-install` manifests (includes CRDs)
   - Application definitions in `argocd-apps`
   - Extra configurations in `argocd-extra`

9. **Cluster Reset**: `ansible/reset_k0s.yaml` playbook can reset the cluster
   - Use with extreme caution, especially in production
   - Completely wipes k0s state and requires re-bootstrap

10. **Git Commits**: Always verify staged files before committing:
   - Do NOT use `git add -A` (includes untracked files)
   - Run `git status` and `git diff --cached` to verify what will be committed
   - Only commit explicitly staged files
   - Use `git restore --staged <file>` to unstage unwanted files

## File Organization Summary

- **`terraform/env/`**: Environment-specific Terraform configurations
  - `dev/`: Development environment configuration
  - `prod/`: Production environment configuration
- **`terraform/modules/`**: Reusable Terraform modules
  - `k8s_nodes/`: Infrastructure module for cluster provisioning
  - `ansible_inventory/`: Dynamic Ansible inventory generation
- **`ansible/`**: Cluster setup automation
  - `roles/`: 12 Ansible roles for cluster configuration
  - `plugins/lookup/`: Custom lookup plugin for Sakura Secret Manager
  - `setup.yaml`: Main playbook for cluster setup
  - `reset_k0s.yaml`: Cluster reset playbook
  - `pyproject.toml` & `uv.lock`: Python dependencies managed via uv
- **`manifests/`**: 14 Kubernetes component directories using Kustomize
  - Each with base/, dev/, prod/ overlays (and crds/, components/ where applicable)
- **`Makefile`**: Command wrappers for Terraform, Ansible, and Kustomize operations
- **`aqua.yaml`**: Declarative CLI tool version management (tenv, uv, kustomize, usacloud, etc.)
- **`.github/`**: GitHub Actions workflows for CI/CD (actionlint, autofix, trivy scanning)

## Customization Points

- **Environment**: Two environments are available: `dev` (default) and `prod`
  - Override with `ENV=prod make tf-plan` or `ENV=prod make ansible-apply`
  - Each environment has its own Terraform state and Sakura Secret Manager vault
- **Node Counts**: Configure `cplane_nodes` and `worker_nodes` in respective `terraform/env/{dev,prod}/main.tf`
  - Control plane nodes must be an odd number (default: 3)
  - Worker nodes minimum 1 (default: 3)
- **Network Configuration**:
  - Modify variables passed to `k8s_nodes` module in environment-specific `main.tf`
  - IPv6 CIDR subnetting for NAT64 box, control plane, and worker nodes
  - LoadBalancer IPv4 address count (default: 4)
- **Cilium Configuration**: Edit `manifests/cilium/{dev,prod}/kustomization.yaml` to customize Helm values
- **Manifest Overlays**: Each component supports dev/prod overlays for environment-specific configuration
- **Manifest Generation**: Run `make manifests` to generate all manifests (CRDs, dev, and prod)