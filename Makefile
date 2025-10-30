ENV ?= dev

.PHONY: fmt validate

fmt: tf-fmt

validate: tf-validate ansible-validate

# Terraform targets
TF_DIR = terraform/env/$(ENV)
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required

.PHONY: tf-init tf-plan tf-apply tf-fmt tf-validate

tf-init:
	terraform -chdir=$(TF_DIR) init

tf-plan: tf-init
	terraform -chdir=$(TF_DIR) plan

tf-apply: tf-init
	terraform -chdir=$(TF_DIR) apply

tf-fmt:
	terraform fmt -recursive terraform/

tf-validate: $(TF_DIR)/.terraform
	terraform -chdir=$(TF_DIR) validate

$(TF_DIR)/.terraform:
	terraform -chdir=$(TF_DIR) init -backend=false

# Ansible targets
.PHONY: ansible-apply ansible-validate

ansible-apply: manifests
	cd ansible && uv run ansible-playbook setup.yaml

ansible-validate:
	cd ansible && uv run ansible-lint setup.yaml reset_k0s.yaml

# Kubernetes manifest build pattern rule
MANIFESTS_DIR = $(wildcard manifests/*)
MANIFESTS = $(addsuffix /dev.generated.yaml,$(MANIFESTS_DIR))
CHARTS_DEV = $(addsuffix /dev/charts,$(MANIFESTS_DIR))
CHARTS_BASE = $(addsuffix /base/charts,$(MANIFESTS_DIR))

.PHONY: manifests clean-manifests

manifests: $(MANIFESTS)

clean-manifests:
	rm -f $(MANIFESTS)
	rm -rf $(CHARTS_DEV) $(CHARTS_BASE)

manifests/%/dev.generated.yaml: manifests/%/dev/* $(wildcard manifests/%/base/*)
	kustomize build --enable-helm --load-restrictor LoadRestrictionsNone $(@D)/dev > $@
