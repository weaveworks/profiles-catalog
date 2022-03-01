# include Makefile.capi

SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')



export CLUSTER_NAME=mvm-test
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
export CONTROL_PLANE_VIP=192.168.1.25
export HOST_ENDPOINT=192.168.1.3:9090
export CAPMVM_VERSION=v0.2.2
export EXP_CLUSTER_RESOURCE_SET=true
export KUBERNETES_VERSION=v1.21.8
export MVM_ROOT_IMAGE=ghcr.io/weaveworks/capmvm-kubernetes:1.21.8
export MVM_KERNEL_IMAGE=ghcr.io/weaveworks/flintlock-kernel:5.10.77

##@ https://github.com/weaveworks/cluster-api-provider-microvm/blob/main/docs/compatibility.md
CONFDIR="${PWD}/../../.conf"
GITHUB_USERNAME=steve-fraser

MVM_MGMT_CLUSTER=mvm-mgmt-profiles-cluster
MVM_KIND_CLUSTER=mvm-bootstrap-cluster
MVM_CLUSTER_NAMESPACE?=default

create-mvm-mgmt-cluster: create-mvm-bootstrap-cluster configure-and-install-mvm-provider generate-mgmt-cluster-config apply-mgmt-cluster-config

##@ Purpose: Post cluster creations with kubeconfig already configured to install mvm provider
configure-and-install-mvm-provider: add-provider-to-clusterctl create-image-pull-secret install-cert-manager initialize-mvm-provider


check-metal-cli:
	@which metal >/dev/null 2>&1 || (echo "metal binary not found, installing ..." && \
	curl -s -L "https://github.com/equinix/metal-cli/releases/download/v0.7.3/metal-${OS}-amd64" -o metal && \
	chmod +x metal && \
	sudo mv ./metal /usr/local/bin/metal && \
	metal -v)

generate-mgmt-cluster-config:
	@echo "Generating mvm mgmt config..."
	clusterctl generate cluster -n $(MVM_CLUSTER_NAMESPACE) -i microvm:$(CAPMVM_VERSION) -f cilium $(MVM_MGMT_CLUSTER) > $(CONFDIR)/mvm-mgmt-cluster.yaml

apply-mgmt-cluster-config:
	@echo "Applying mvm mgmt config..."
	kubectl apply -f $(CONFDIR)/mvm-mgmt-cluster.yaml


initialize-mvm-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure microvm --wait-providers || true

add-provider-to-clusterctl:
	@echo "Replacing clusterctl config..."
	mkdir -p ~/.cluster-api && \
	cp $(CONFDIR)/clusterctl.config ~/.cluster-api/clusterctl.yaml

create-image-pull-secret:
	@echo "Create image pull secrets" 
	kubectl create namespace capmvm-system || true && \
	kubectl create secret docker-registry -n capmvm-system capmvm-private-image-cred \
	--docker-server=ghcr.io \
	--docker-username=$(GITHUB_USERNAME) \
	--docker-password=$(GITHUB_TOKEN) || true

install-cert-manager:
	@echo "Install cert-manager" 
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.5.3/cert-manager.crds.yaml  &&\
	helm install cert-manager jetstack/cert-manager \
  	--namespace cert-manager \
  	--create-namespace \
  	--version v1.5.3

get-mvm-mgmt-config:
	kubectl get secret ${MVM_MGMT_CLUSTER}-kubeconfig -o json | jq -r .data.value | base64 -d > config.yaml

create-mvm-bootstrap-cluster:
	kind get clusters | grep ${MVM_KIND_CLUSTER} || kind create cluster --name ${MVM_KIND_CLUSTER}

delete-bootstrap-cluster:
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusters.cluster.x-k8s.io $(MVM_KIND_CLUSTER)
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusterresourceset.addons.cluster.x-k8s.io/crs-cilium
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s configmap/cilium-addon

create-namespace:
	kubectl create ns $(MVM_CLUSTER_NAMESPACE)

set-kubeconfig:
	@echo "Setting kubeconfig ..."
	echo ${MVM_MGMT_KUBECONFIG} > /tmp/config.yaml



create-test-cluster: set-kubeconfig