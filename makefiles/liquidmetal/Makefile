include Makefile.capi

SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')



CLUSTER_NAME=mvm-test
CONTROL_PLANE_MACHINE_COUNT=1
WORKER_MACHINE_COUNT=1
CONTROL_PLANE_VIP=<ADDRESS>
HOST_ENDPOINT=<FLINTLOCK_ADDRESS>:9090
##@ https://github.com/weaveworks/cluster-api-provider-microvm/blob/main/docs/compatibility.md
CAPMVM_VERSION=v0.4.0
FLINTLOCK_VERSION=v0.1.0-alpha.8

check-metal-cli:
	@which metal >/dev/null 2>&1 || (echo "metal binary not found, installing ..." && \
	curl -s -L "https://github.com/equinix/metal-cli/releases/download/v0.7.3/metal-${OS}-amd64" -o metal && \
	chmod +x metal && \
	sudo mv ./metal /usr/local/bin/metal && \
	metal -v)

generate-cluster-config:
	clusterctl generate cluster -i microvm:$CAPMVM_VERSION -f cilium $CLUSTER_NAME > cluster.yaml

initialize-mvm-provider:
	@echo "Initialize mvm provider in kind management cluster ..."
	clusterctl init --infrastructure docker --wait-providers || true