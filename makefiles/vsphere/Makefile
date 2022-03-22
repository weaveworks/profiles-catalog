SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')

CLUSTER_NAME?=test-cluster

VSPHERE_PROVIDER_VERSION=v1.1.1

export VSPHERE_USERNAME=administrator@vsphere.local
export VSPHERE_SERVER=192.168.1.93
export VSPHERE_DATACENTER=dc1
export VSPHERE_DATASTORE=datastore1
export VSPHERE_NETWORK=VM Network
export VSPHERE_RESOURCE_POOL=10.68.184.138/Resources
export VSPHERE_FOLDER=
export VSPHERE_TEMPLATE=ubuntu-1804-kube-v1.19.1
export CONTROL_PLANE_ENDPOINT_IP=192.168.1.21
export VIP_NETWORK_INTERFACE=eth0
export VSPHERE_TLS_THUMBPRINT=05:53:0C:77:B9:64:22:E1:D9:54:37:76:80:2B:D3:0E:FE:54:94:E0
export EXP_CLUSTER_RESOURCE_SET=true
export VSPHERE_SSH_AUTHORIZED_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDkfU6iwJaTc17NfCRlAxYx9rrPMEh4jh25NWMBW8xpysMb7yS1cfkAhab917a6XQ9tyj6axXnKMfufAPBkBA6B/SpKhBVcg1TgqS3Kg0nTL6TbpG31wTLt2tfEAzn/5gpLWjjwE7T4lrj2LYqOpyJwCRbroLUc7nIqEAPnUMxfMwfeTlXQVeyN7FFEkrKdNN+Qo2lirS8kcGSBGEt5zvKjytQCebTsFID5XJVGv5VdasZun9NrN9SwUSIfXhUleYG7QTOvaPT7//Vy/OFaW1GN1wR1nFZvXOxJ5kjBe/PVSdG64mLhhT6YFwi32m1wqzuD1Ij4XVjwCMXmK4G2EBfYezoph681eQ6vyU3Pz/qDM+TcbJGyhUn/ARNrnXlU+66QtFCDk0LY+Q50JZkrQxJJb0+awohul32sOp6i1Y5SjlhcSMdB6JXejTMK12EF6W21rrCvPaa0mF6/1xuTIZ5cZwGqSNLjeXf+B6tKEqy8UHnmCx8f5nb21x3umiqAW/c= steve@Stevens-MacBook-Pro.local
export VSPHERE_STORAGE_POLICY=
export KUBERNETES_VERSION=v1.19.1

NUMBER_OF_WORKERS=3
NUMBER_OF_MGMT=3

initialize-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure vsphere:$(VSPHERE_PROVIDER_VERSION) --wait-providers || true

apply-mgmt-cluster-config:
	@echo "Generating mvm test config..."
	kubectl apply -f /tmp/vsphere-test-cluster.yaml

generate-mgmt-cluster-config:
	@echo "Generating mvm test config..."
	clusterctl generate cluster $(CLUSTER_NAME) \
	-n default \
	--from ./template.yaml \
    --control-plane-machine-count $(NUMBER_OF_MGMT) \
    --worker-machine-count  $(NUMBER_OF_WORKERS) > /tmp/vsphere-test-cluster.yaml

generate-test-cluster-config:
	@echo "Generating mvm test config..."
	clusterctl generate cluster $(CLUSTER_NAME) \
	-n $(CLUSTER_NAME) \
	--from ./template.yaml \
    --control-plane-machine-count $(NUMBER_OF_MGMT) \
    --worker-machine-count  $(NUMBER_OF_WORKERS) > /tmp/vsphere-test-cluster.yaml

add-provider-to-clusterctl:
	@echo "Replacing clusterctl config..."
	mkdir -p ~/.cluster-api && \
	cp clusterctl.config ~/.cluster-api/clusterctl.yaml

check-requirements: add-provider-to-clusterctl



create-mvm-mgmt-cluster: create-mvm-bootstrap-cluster configure-and-install-mvm-provider generate-mgmt-cluster-config apply-mgmt-cluster-config

setup-mgmt-cluster: initialize-provider generate-mgmt-cluster-config apply-mgmt-cluster-config