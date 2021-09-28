SHELL: /bin/bash
.ONESHELL:

.DEFAULT_GOAL := local-env

##@ Versions
CILIUM_VERSION=1.9.10
CLUSTERCTL_VERSION=0.4.2
GITOPS_VERSION=0.3.0
KIND_VERSION=0.11.1
K8S_VERSION=1.21.1
PCTL_VERSION=0.10.0

OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"
KIND_CLUSTER=banan



##@ Requirements
check-requirements: check-gitops check-clusterctl check-pctl check-kind

check-gitops:
	@which gitops >/dev/null 2>&1 || (echo "gitops binary not found, installing ..." && \
	curl -s -L "https://github.com/weaveworks/weave-gitops/releases/download/v${GITOPS_VERSION}/gitops-$(shell uname)-$(shell uname -m)" -o gitops && \
	chmod +x gitops && \
	sudo mv ./gitops /usr/local/bin/gitops && \
	gitops version)

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && \
	curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && \
	chmod +x clusterctl && \
	sudo mv ./clusterctl /usr/local/bin/clusterctl && \
	clusterctl version)

check-pctl:
	@which pctl >/dev/null 2>&1 || (echo "pctl binary not found, installing ..." && \
	wget "https://github.com/weaveworks/pctl/releases/download/v${PCTL_VERSION}/pctl_${OS}_amd64.tar.gz" && \
	tar xvfz pctl_${OS}_amd64.tar.gz && \
	sudo mv ./pctl /usr/local/bin/pctl && \
	pctl --version )

check-kind:
	@which kind  >/dev/null 2>&1 || (echo "kind binary not found, installing ..." && \
	curl -s -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-amd64 && \
	chmod +x ./kind && \
	mv ./kind /usr/local/bin/kind && \
	kind version)

check-config-dir:
	@echo "Check if config folder exists ...";
	[ -d ${CONFDIR} ] || mkdir ${CONFDIR}

##@ Cluster
create-cluster:
	@echo "Creating kind management cluster ...";
	kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --config ${BINDIR}/kind-cluster-with-extramounts.yaml --name ${KIND_CLUSTER}
	

local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing