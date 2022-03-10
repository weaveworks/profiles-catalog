SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')

TEST_CLUSTER_NAME?=test-cluster

# ## -- Controller settings -- ##
VSPHERE_PROVIDER_VERSION=v1.1.0

export VSPHERE_USERNAME=administrator@vsphere.local
## -- Required workload cluster default settings -- ##
export VSPHERE_SERVER=192.168.1.77
export VSPHERE_DATACENTER=dc1
export VSPHERE_DATASTORE=datastore1
export VSPHERE_NETWORK=VM Network
export VSPHERE_RESOURCE_POOL=147.28.150.74/Resources
export VSPHERE_FOLDER=
export VSPHERE_TEMPLATE=ubuntu-1804-kube-v1.17.3
export CONTROL_PLANE_ENDPOINT_IP=192.168.1.22
export VIP_NETWORK_INTERFACE="ens192"
export VSPHERE_TLS_THUMBPRINT=69:0F:22:46:B4:94:3B:03:CF:7F:0C:CF:BC:40:80:4B:B9:EF:FB:E5
export EXP_CLUSTER_RESOURCE_SET="true"
export VSPHERE_SSH_AUTHORIZED_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDkfU6iwJaTc17NfCRlAxYx9rrPMEh4jh25NWMBW8xpysMb7yS1cfkAhab917a6XQ9tyj6axXnKMfufAPBkBA6B/SpKhBVcg1TgqS3Kg0nTL6TbpG31wTLt2tfEAzn/5gpLWjjwE7T4lrj2LYqOpyJwCRbroLUc7nIqEAPnUMxfMwfeTlXQVeyN7FFEkrKdNN+Qo2lirS8kcGSBGEt5zvKjytQCebTsFID5XJVGv5VdasZun9NrN9SwUSIfXhUleYG7QTOvaPT7//Vy/OFaW1GN1wR1nFZvXOxJ5kjBe/PVSdG64mLhhT6YFwi32m1wqzuD1Ij4XVjwCMXmK4G2EBfYezoph681eQ6vyU3Pz/qDM+TcbJGyhUn/ARNrnXlU+66QtFCDk0LY+Q50JZkrQxJJb0+awohul32sOp6i1Y5SjlhcSMdB6JXejTMK12EF6W21rrCvPaa0mF6/1xuTIZ5cZwGqSNLjeXf+B6tKEqy8UHnmCx8f5nb21x3umiqAW/c= steve@weaveworks
export VSPHERE_STORAGE_POLICY=
export KUBERNETES_VERSION=v1.17.3

initialize-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure vsphere --wait-providers || true


generate-test-cluster-config:
	@echo "Generating mvm test config..."
	clusterctl generate cluster $(TEST_CLUSTER_NAME) \
    --infrastructure vsphere:$(VSPHERE_PROVIDER_VERSION) \
	-n $(TEST_CLUSTER_NAME) \
    --control-plane-machine-count 1 \
    --worker-machine-count 0 > /tmp/vsphere-test-cluster.yaml

add-provider-to-clusterctl:
	@echo "Replacing clusterctl config..."
	mkdir -p ~/.cluster-api && \
	cp clusterctl.config ~/.cluster-api/clusterctl.yaml

check-requirements: add-provider-to-clusterctl