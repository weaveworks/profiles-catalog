SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')

CLUSTER_NAME?=test-cluster

VSPHERE_PROVIDER_VERSION=v1.1.1

export VSPHERE_USERNAME=administrator@vsphere.local

export VSPHERE_SERVER=192.168.1.77
export VSPHERE_DATACENTER=dc1
export VSPHERE_DATASTORE=datastore1
export VSPHERE_NETWORK=VM Network
export VSPHERE_RESOURCE_POOL=147.28.150.74/Resources
export VSPHERE_FOLDER=
export VSPHERE_TEMPLATE=ubuntu-1804-kube-v1.17.3
export CONTROL_PLANE_ENDPOINT_IP=192.168.1.21
export VIP_NETWORK_INTERFACE=ens192
export VSPHERE_TLS_THUMBPRINT=69:0F:22:46:B4:94:3B:03:CF:7F:0C:CF:BC:40:80:4B:B9:EF:FB:E5
export EXP_CLUSTER_RESOURCE_SET=true
export VSPHERE_SSH_AUTHORIZED_KEY=
export VSPHERE_STORAGE_POLICY=
export KUBERNETES_VERSION=v1.17.3

NUMBER_OF_WORKERS=3
NUMBER_OF_MGMT=3

initialize-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure vsphere:$(VSPHERE_PROVIDER_VERSION) --wait-providers || true


generate-test-cluster-config:
	@echo "Generating mvm test config..."
	clusterctl generate cluster $(CLUSTER_NAME) \
    --infrastructure vsphere:$(VSPHERE_PROVIDER_VERSION) \
	-n $(CLUSTER_NAME) \
    --control-plane-machine-count $(NUMBER_OF_MGMT)\
    --worker-machine-count  $(NUMBER_OF_WORKERS) > /tmp/vsphere-test-cluster.yaml

add-provider-to-clusterctl:
	@echo "Replacing clusterctl config..."
	mkdir -p ~/.cluster-api && \
	cp clusterctl.config ~/.cluster-api/clusterctl.yaml

check-requirements: add-provider-to-clusterctl