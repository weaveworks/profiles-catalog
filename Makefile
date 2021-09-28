SHELL: /bin/bash

GITOPS_VERSION=0.3.0
PCTL_VERSION=0.10.0
K8S_VERSION=1.21.1
CILIUM_VERSION=1.9.10
CLUSTERCTL_VERSION=0.4.2
OS := $(shell uname | tr '[:upper:]' '[:lower:]')

.ONESHELL:

.DEFAULT_GOAL := local-env

##@ Requirements
check-requirements: check-gitops check-clusterctl check-pctl

check-gitops:
	@which gitops >/dev/null 2>&1 || (echo "gitops binary not found, installing ..." && curl -s -L "https://github.com/weaveworks/weave-gitops/releases/download/v${GITOPS_VERSION}/gitops-$(shell uname)-$(shell uname -m)" -o gitops && chmod +x gitops && sudo mv ./gitops /usr/local/bin/gitops && gitops version)

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && chmod +x clusterctl && sudo mv ./clusterctl /usr/local/bin/clusterctl && clusterctl version)

check-pctl:
	@which pctl >/dev/null 2>&1 || (echo "pctl binary not found, installing ..." && wget "https://github.com/weaveworks/pctl/releases/download/v${PCTL_VERSION}/pctl_${OS}_amd64.tar.gz"; tar xvfz pctl_${OS}_amd64.tar.gz; sudo mv ./pctl /usr/local/bin/pctl; pctl --version )

##@ Cluster
local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing