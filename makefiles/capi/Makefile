SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/../.conf"
BINDIR="${PWD}/../../.bin"
REPODIR="${PWD}/../charts"

INFRASTRUCTURE?="kind"
CLUSTER_NAME?=test-cluster

CLUSTERCTL_VERSION=1.0.2

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && \
	curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && \
	chmod +x clusterctl && \
	sudo mv ./clusterctl /usr/local/bin/clusterctl && \
	clusterctl version)

generate-test-cluster-config: 
	cd $(PWD)/../${INFRASTRUCTURE} && $(MAKE) generate-test-cluster-config

apply-test-cluster-config:
	@echo "Applying test config..."
	kubectl create ns $(CLUSTER_NAME) 
	kubectl apply -f /tmp/${INFRASTRUCTURE}-test-cluster.yaml

initialize-provider:
	cd $(PWD)/../${INFRASTRUCTURE} && $(MAKE) initialize-provider

check-requirements:
	cd $(PWD)/../${INFRASTRUCTURE} && $(MAKE) check-requirements

pick-vip-address:
	bash ${BINDIR}/select-vip-for-clusterapi.sh


wait-until-master-is-ready:
	kubectl wait --for=jsonpath='{.status.phase}'=Provisioned --timeout=15m Clusters -n profiles-vsphere-418 profiles-vsphere-418

##TEMP: Currently required because a calico template is not included in micovm-capi releases and linkerd is having issues with cilium
install-single-node-calico:
	@echo "Installing Calico..."
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml create  -f calico.yaml
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml wait --for=jsonpath='{.status.numberReady}'=1 ds --timeout=900s -n kube-system calico-node
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml wait --timeout=3m -n kube-system --for=condition=ready pod -l k8s-app=calico-node 

install-ha-calico:
	@echo "Installing Calico..."
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml create  -f calico.yaml
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml wait --for=jsonpath='{.status.numberReady}'=6 ds --timeout=900s -n kube-system calico-node
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml wait --timeout=3m -n kube-system --for=condition=ready pod -l k8s-app=calico-node 

#Currently required because the cni is not installed yet when the inital dns pods are installed, so they need to be restarted for them to be created with cni
restart-coredns:
	@echo "Patching CoreDNS..."
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml rollout restart deployment/coredns -n kube-system	

unlabel-master:
	@echo "Removing taint of masters..."
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml taint nodes --all node-role.kubernetes.io/master-
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml taint nodes --all node.cloudprovider.kubernetes.io/uninitialized- || true

wait-for-nodes:
	@echo "Waiting for nodes to be ready..."
	kubectl --kubeconfig=/tmp/${INFRASTRUCTURE}-testing-config.yaml wait --for=condition=Ready nodes --all --timeout=600s



get-testing-config:
	kubectl get secret -n $(CLUSTER_NAME) $(CLUSTER_NAME)-kubeconfig -o json | jq -r .data.value | base64 -d > /tmp/${INFRASTRUCTURE}-testing-config.yaml

delete-test-cluster:
	@echo "Deleting test cluster..."
	kubectl delete -n $(CLUSTER_NAME) --wait=true --timeout=900s clusters.cluster.x-k8s.io $(CLUSTER_NAME)
	kubectl delete ns --wait=true --timeout=900s $(CLUSTER_NAME) 

create-test-cluster: create-ha-test-cluster

create-single-node-test-cluster: check-clusterctl check-requirements pick-vip-address generate-test-cluster-config apply-test-cluster-config wait-until-master-is-ready get-testing-config install-single-node-calico wait-for-nodes unlabel-master restart-coredns

create-ha-test-cluster: check-clusterctl check-requirements pick-vip-address generate-test-cluster-config apply-test-cluster-config wait-until-master-is-ready get-testing-config install-ha-calico wait-for-nodes restart-coredns
