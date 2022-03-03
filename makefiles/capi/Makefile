SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"
REPODIR="${PWD}/charts"

GKE_CLUSTER_NAME?="weave-profiles-capi"
GCP_REGION="us-west1"
GCP_PROJECT_NAME="weave-profiles"
GCP_NUM_NODES=1
GCP_MACHINE_TYPE=e2-standard-4


CLUSTERCTL_VERSION=1.0.2


provision-capi-cluster: check-clusterctl create-capi-cluster

create-capi-cluster:
	gcloud container clusters create ${GKE_CLUSTER_NAME} --region ${GCP_REGION} -m ${GCP_MACHINE_TYPE}  --num-nodes=${GCP_NUM_NODES} --project ${GCP_PROJECT_NAME}

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && \
	curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && \
	chmod +x clusterctl && \
	sudo mv ./clusterctl /usr/local/bin/clusterctl && \
	clusterctl version)

#bump bump