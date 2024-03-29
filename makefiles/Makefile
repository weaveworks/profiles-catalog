SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/../.conf"
BINDIR="${PWD}/.bin"
REPODIR="${PWD}/charts"
INFRASTRUCTURE?="kind"

CLUSTER_NAME?=test-cluster

AWS_REGION="us-west-1"
NODEGROUP_NAME="ng-1"
NODE_INSTANCE_TYPE="m5.large"
NUM_OF_NODES="2"
EKS_K8S_VERSION="1.21"

GKE_CLUSTER_NAME?="weave-profiles-test-cluster"
GCP_REGION="us-west1"
GCP_PROJECT_NAME="weave-profiles"
GCP_NUM_NODES=1
GCP_MACHINE_TYPE=e2-standard-4


test:
	@echo "Testing platform"
	bash ${BINDIR}/test-platform.sh ${INFRASTRUCTURE}

sort-layers:
	@echo "Sorting charts by layers"
	bash ${BINDIR}/sort-layers.sh

##@ Cluster
create-cluster:
	@if [ ${INFRASTRUCTURE} = "kind" ]; then\
		echo "Creating kind management cluster ...";
		kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --config ${BINDIR}/kind-cluster-with-extramounts.yaml --name ${KIND_CLUSTER}
	elif [ ${INFRASTRUCTURE} = "eks" ]; then\
		echo "Creating eks cluster ..."
		eksctl create cluster --name ${CLUSTER_NAME} \
			--region ${AWS_REGION} \
			--version ${EKS_K8S_VERSION} \
			--nodegroup-name ${NODEGROUP_NAME} \
			--node-type ${NODE_INSTANCE_TYPE} \
			--nodes ${NUM_OF_NODES}
	elif [ ${INFRASTRUCTURE} = "gke" ]; then\
		echo "Creating gke cluster ..."
		gcloud container clusters create ${GKE_CLUSTER_NAME} --region ${GCP_REGION} -m ${GCP_MACHINE_TYPE}  --num-nodes=${GCP_NUM_NODES} --project ${GCP_PROJECT_NAME}
	elif [ ${INFRASTRUCTURE} = "mvm" ]; then\
		echo "Creating mvm cluster ..."
		cd $(PWD)/makefiles/capi && INFRASTRUCTURE=${INFRASTRUCTURE} $(MAKE) create-test-cluster
	elif [ ${INFRASTRUCTURE} = "vsphere" ]; then\
		echo "Creating mvm cluster ..."
		cd $(PWD)/makefiles/capi && INFRASTRUCTURE=${INFRASTRUCTURE} $(MAKE) create-test-cluster
	fi

delete-cluster: 
	@if [ ${INFRASTRUCTURE} = "kind" ]; then\
		echo "Deleting kind cluster ..."
		kind delete cluster --name ${KIND_CLUSTER}
	elif [ ${INFRASTRUCTURE} = "eks" ]; then\
		echo "Deleting eks cluster ..."
		eksctl delete cluster --region ${AWS_REGION} --name ${CLUSTER_NAME} --wait || \
		aws cloudformation delete-stack --region ${AWS_REGION} --stack-name eksctl-${CLUSTER_NAME}-cluster
	elif [ ${INFRASTRUCTURE} = "mvm" ]; then\
		echo "Deleting mvm cluster ..."
		cd $(PWD)/makefiles/capi && $(MAKE) delete-test-cluster
	elif [ ${INFRASTRUCTURE} = "vsphere" ]; then\
		echo "Deleting vsphere cluster ..."
		cd $(PWD)/makefiles/capi && $(MAKE) delete-test-cluster
	elif [ ${INFRASTRUCTURE} = "gke" ]; then\
		echo "Deleting gke cluster ..."
		gcloud container clusters delete ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_NAME} -q
	fi

check-eksctl:
	@which eksctl  >/dev/null 2>&1 || (echo "eksctl binary not found, installing ..." && \
	curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${OS}_amd64.tar.gz" | tar xz -C /tmp && \
	chmod +x /tmp/eksctl && \
	sudo mv /tmp/eksctl /usr/local/bin && \
	eksctl version)
