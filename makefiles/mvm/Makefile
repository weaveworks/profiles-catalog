# include Makefile.capi

SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')



export MVM_CLUSTER_NAME?=mvm-test
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

pick-vip-address:
	bash ${BINDIR}/select-vip-for-mvm.sh


generate-test-cluster-config:
	@echo "Generating mvm test config..." 
	CONTROL_PLANE_VIP=$(shell cat /tmp/mvm-vip) clusterctl generate cluster -n $(MVM_CLUSTER_NAME) -i microvm:$(CAPMVM_VERSION) $(MVM_CLUSTER_NAME) > /tmp/mvm-test-cluster.yaml

apply-mgmt-cluster-config:
	@echo "Applying mvm mgmt config..."
	kubectl apply -f $(CONFDIR)/mvm-mgmt-cluster.yaml

apply-test-cluster-config:
	@echo "Applying mvm test config..."
	kubectl create ns $(MVM_CLUSTER_NAME) 
	kubectl apply -f /tmp/mvm-test-cluster.yaml

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

get-testing-config:
	kubectl get secret -n $(MVM_CLUSTER_NAME) $(MVM_CLUSTER_NAME)-kubeconfig -o json | jq -r .data.value | base64 -d > /tmp/mvm-testing-config.yaml
	export KUBECONFIG=/tmp/mvm-testing-config.yaml



create-mvm-bootstrap-cluster:
	kind get clusters | grep ${MVM_KIND_CLUSTER} || kind create cluster --name ${MVM_KIND_CLUSTER}

delete-bootstrap-cluster:
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusters.cluster.x-k8s.io $(MVM_KIND_CLUSTER)
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s clusterresourceset.addons.cluster.x-k8s.io/crs-cilium
	kubectl delete -n $(MVM_CLUSTER_NAMESPACE) --wait=true --timeout=900s configmap/cilium-addon

create-namespace:
	kubectl create ns $(MVM_CLUSTER_NAMESPACE)


check-requirements:
	@echo "Getting requirements..."
	cd $(PWD)/../capi && $(MAKE) check-clusterctl


wait-until-master-is-ready:
	kubectl wait --for=condition=ready --timeout=15m Clusters -n $(MVM_CLUSTER_NAME) $(MVM_CLUSTER_NAME)
	kubectl wait --for=condition=ready --timeout=15m Kubeadmcontrolplanes -l cluster.x-k8s.io/cluster-name=$(MVM_CLUSTER_NAME) -n  $(MVM_CLUSTER_NAME) 

delete-test-cluster:
	@echo "Deleting mvm test cluster..."
	kubectl delete -n $(MVM_CLUSTER_NAME) --wait=true --timeout=900s clusters.cluster.x-k8s.io $(MVM_CLUSTER_NAME)
	kubectl delete ns --wait=true --timeout=900s $(MVM_CLUSTER_NAME) 

##TEMP: Currently required because a calico template is not included in micovm-capi releases and linkerd is having issues with cilium
install-calico:
	@echo "Installing Calico..."
	kubectl create  -f calico.yaml
	kubectl wait --for=condition=Ready nodes --all --timeout=600s
	kubectl wait --timeout=3m  -n kube-system --for=condition=ready pod -l k8s-app=calico-kube-controllers 
	kubectl wait --timeout=3m -n kube-system --for=condition=ready pod -l k8s-app=calico-node 

#Currently required because the cni is not installed yet when the inital dns pods are installed, so they need to be restarted for them to be created with sni
restart-coredns:
	@echo "Patching CoreDNS..."
	kubectl rollout restart deployment/coredns -n kube-system	

unlabel-master:
	@echo "Removing taint of masters..."
	kubectl taint nodes --all node-role.kubernetes.io/master-

#create-test-cluster: check-requirements add-provider-to-clusterctl pick-vip-address generate-test-cluster-config apply-test-cluster-config wait-until-master-is-ready get-testing-config install-calico restart-coredns
create-test-cluster: check-requirements add-provider-to-clusterctl pick-vip-address generate-test-cluster-config apply-test-cluster-config wait-until-master-is-ready get-testing-config unlabel-master install-calico restart-coredns
