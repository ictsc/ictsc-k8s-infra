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
	cd ansible && ENV=$(ENV) uv run ansible-playbook setup.yaml

ansible-validate:
	cd ansible && uv run ansible-lint setup.yaml reset_k0s.yaml

# Kubernetes manifest build pattern rule
MANIFESTS_DIR := $(wildcard manifests/*)
MANIFESTS := $(addsuffix /dev.generated.yaml,$(MANIFESTS_DIR))
CHARTS := $(addsuffix /dev/charts,$(MANIFESTS_DIR)) $(addsuffix /base/charts,$(MANIFESTS_DIR))

CRD_MANIFESTS := $(addsuffix crds.generated.yaml,$(dir $(wildcard manifests/*/crds)))
PROD_MANIFESTS := $(addsuffix prod.generated.yaml,$(dir $(wildcard manifests/*/prod)))

.PHONY: manifests clean-manifests

manifests: $(CRD_MANIFESTS) $(PROD_MANIFESTS) $(MANIFESTS)

clean-manifests:
	rm -f $(CRD_MANIFESTS) $(PROD_MANIFESTS)
	rm -rf $(CHARTS)
	rm -f $(MANIFESTS)

.SECONDEXPANSION:
manifests/%/crds.generated.yaml: $$(shell find manifests/$$*/crds -type f 2>/dev/null)
	kustomize build --enable-helm --load-restrictor LoadRestrictionsNone manifests/$*/crds > $@

manifests/%/dev.generated.yaml: $$(shell find manifests/$$*/dev manifests/$$*/base manifests/$$*/components -type f 2>/dev/null)
	kustomize build --enable-helm --load-restrictor LoadRestrictionsNone manifests/$*/dev > $@

manifests/%/prod.generated.yaml: $$(shell find manifests/$$*/prod manifests/$$*/base manifests/$$*/components -type f 2>/dev/null)
	kustomize build --enable-helm --load-restrictor LoadRestrictionsNone manifests/$*/prod > $@
