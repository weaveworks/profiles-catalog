# include Makefile.capi

SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')



export CLUSTER_NAME?=mvm-test
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=0


CONTROL_PLANE_VIP_MGMT=192.168.1.25

export HOST_ENDPOINT=10.68.184.131:9090

##@ https://github.com/weaveworks/cluster-api-provider-microvm/blob/main/docs/compatibility.md
export CAPMVM_VERSION=v0.2.2
export EXP_CLUSTER_RESOURCE_SET=true
export KUBERNETES_VERSION=v1.21.8
export MVM_ROOT_IMAGE=ghcr.io/weaveworks/capmvm-kubernetes:1.21.8
export MVM_KERNEL_IMAGE=ghcr.io/weaveworks/flintlock-kernel:5.10.77

CONFDIR="$(PWD)/../../.conf"
BINDIR="${PWD}/../../.bin"


GITHUB_USERNAME=steve-fraser

MVM_MGMT_CLUSTER=mvm-mgmt-profiles-cluster
MVM_KIND_CLUSTER=mvm-bootstrap-cluster

create-mvm-mgmt-cluster: create-mvm-bootstrap-cluster configure-and-install-mvm-provider generate-mgmt-cluster-config apply-mgmt-cluster-config

##@ Purpose: Post cluster creations with kubeconfig already configured to install mvm provider
configure-and-install-mvm-provider: add-provider-to-clusterctl create-image-pull-secret install-cert-manager initialize-mvm-provider

##@ Purpose: to install the github runner
install-github-runner:
	helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
	kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=${GITHUB_TOKEN} || true && \
	helm upgrade --install --namespace actions-runner-system --create-namespace \
	--wait actions-runner-controller actions-runner-controller/actions-runner-controller &&\
	kubectl apply -f runner.yaml

generate-mgmt-cluster-config:
	@echo "Generating mvm mgmt config..."
	CONTROL_PLANE_VIP=${CONTROL_PLANE_VIP_MGMT} clusterctl generate cluster -i microvm:$(CAPMVM_VERSION) $(MVM_MGMT_CLUSTER) > $(CONFDIR)/mvm-mgmt-cluster.yaml

generate-test-cluster-config:
	@echo "Generating mvm test config..." 
	CONTROL_PLANE_VIP=$(shell cat /tmp/vip) clusterctl generate cluster -n $(CLUSTER_NAME) -i microvm:$(CAPMVM_VERSION) $(CLUSTER_NAME) > /tmp/mvm-test-cluster.yaml

apply-mgmt-cluster-config:
	@echo "Applying mvm mgmt config..."
	kubectl apply -f $(CONFDIR)/mvm-mgmt-cluster.yaml

initialize-mvm-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure microvm --wait-providers || true

add-provider-to-clusterctl:
	@echo "Replacing clusterctl config..."
	mkdir -p ~/.cluster-api && \
	cp clusterctl.config ~/.cluster-api/clusterctl.yaml

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
	kubectl get secret ${MVM_MGMT_CLUSTER}-kubeconfig -o json | jq -r .data.value | base64 -d > /tmp/config.yaml

create-mvm-bootstrap-cluster:
	kind get clusters | grep ${MVM_KIND_CLUSTER} || kind create cluster --name ${MVM_KIND_CLUSTER}

delete-bootstrap-cluster:
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusters.cluster.x-k8s.io $(MVM_KIND_CLUSTER)
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusterresourceset.addons.cluster.x-k8s.io/crs-cilium
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s configmap/cilium-addon

check-requirements: add-provider-to-clusterctl