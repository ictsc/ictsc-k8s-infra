.PHONY: help init plan apply fmt validate manifests

ENV ?= dev
TF_DIR = terraform/env/$(ENV)
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required

init:
	terraform -chdir=$(TF_DIR) init

plan:
	terraform -chdir=$(TF_DIR) plan

apply:
	terraform -chdir=$(TF_DIR) apply

fmt:
	terraform fmt -recursive terraform/

validate:
	terraform -chdir=$(TF_DIR) validate

# Kubernetes manifest build pattern rule
manifests: manifests/cilium/dev.generated.yaml manifests/rbac/dev.generated.yaml manifests/coredns/dev.generated.yaml

manifests/%/dev.generated.yaml: manifests/%/dev/* manifests/%/base/*
	kustomize build --enable-helm $(dir $<) > $@
