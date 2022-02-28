# include Makefile.capi

SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')



export CLUSTER_NAME=mvm-test
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
export CONTROL_PLANE_VIP=127.0.0.1
export HOST_ENDPOINT=127.0.0.1:9090
export CAPMVM_VERSION=v0.4.0
export FLINTLOCK_VERSION=v0.1.0-alpha.8
##@ https://github.com/weaveworks/cluster-api-provider-microvm/blob/main/docs/compatibility.md
CONFDIR="${PWD}/../../.conf"
GITHUB_USERNAME=steve-fraser

configure-and-install-mvm-provider: add-provider-to-clusterctl create-image-pull-secret install-cert-manager initialize-mvm-provider

check-metal-cli:
	@which metal >/dev/null 2>&1 || (echo "metal binary not found, installing ..." && \
	curl -s -L "https://github.com/equinix/metal-cli/releases/download/v0.7.3/metal-${OS}-amd64" -o metal && \
	chmod +x metal && \
	sudo mv ./metal /usr/local/bin/metal && \
	metal -v)

generate-cluster-config:
	clusterctl generate cluster -i microvm:$(CAPMVM_VERSION) -f cilium $(CLUSTER_NAME) > $(CONFDIR)/cluster.yaml

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