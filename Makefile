SHELL: /bin/bash
.ONESHELL:

.DEFAULT_GOAL := local-env

##@ Versions
CILIUM_VERSION=1.9.10
CLUSTERCTL_VERSION=0.4.2
GITOPS_VERSION=0.3.0
KIND_VERSION=0.11.1
K8S_VERSION=1.21.1
PCTL_VERSION=0.11.0

OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"
REPODIR="${PWD}/.repo"

KIND_CLUSTER=testing

EKS_CLUSTER_NAME="profiles-cluster"
AWS_REGION="us-west-1"
NODEGROUP_NAME="ng-1"
NODE_INSTANCE_TYPE="m5.large"
NUM_OF_NODES="2"
EKS_K8S_VERSION="1.21"

PROFILE=gitops-enterprise-mgmt-eks

TEST_REPO_USER=ww-customer-test
TEST_REPO=profile-test-repo
CATALOG_REPO_URL=git@github.com:weaveworks/profiles-catalog.git





##@ Flows


##@ with-clusterctl: check-requirements create-cluster save-kind-cluster-config initialise-docker-provider generate-manifests-clusterctl

eks: check-requirements set-eks-variables check-eksctl get-eks-kubeconfig change-eks-kubeconfig install-profile-and-sync

kind: check-requirements check-kind create-cluster check-config-dir save-kind-cluster-config change-kubeconfig upload-profiles-image-to-cluster install-profile-and-sync

##@ Post Kubernetes creation with valid KUBECONFIG set it installs gitops and profiles, boostraps cluster, installs profile, and syncs
##@ TODO: Clear current profile is it's there
install-profile-and-sync: install-gitops-on-cluster install-profiles-on-cluster bootstrap-cluster check-repo-dir clone-test-repo create-profile-kustomization add-profile commit-test-repo


##@ validate-configuration

set-eks-variables :
	@echo "setting eks variables";
	TEST_REPO=profile-test-repo-eks

##@ Requirements
check-requirements: check-gitops check-clusterctl check-pctl


check-gitops:
	@which gitops >/dev/null 2>&1 || (echo "gitops binary not found, installing ..." && \
	curl -s -L "https://github.com/weaveworks/weave-gitops/releases/download/v${GITOPS_VERSION}/gitops-$(shell uname)-$(shell uname -m)" -o gitops && \
	chmod +x gitops && \
	sudo mv ./gitops /usr/local/bin/gitops && \
	gitops version)

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && \
	curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && \
	chmod +x clusterctl && \
	sudo mv ./clusterctl /usr/local/bin/clusterctl && \
	clusterctl version)

check-pctl:
	@which pctl >/dev/null 2>&1 || (echo "pctl binary not found, installing ..." && \
	wget "https://github.com/weaveworks/pctl/releases/download/v${PCTL_VERSION}/pctl_${OS}_amd64.tar.gz" && \
	tar xvfz pctl_${OS}_amd64.tar.gz && \
	sudo mv ./pctl /usr/local/bin/pctl && \
	pctl --version )

check-kind:
	@which kind  >/dev/null 2>&1 || (echo "kind binary not found, installing ..." && \
	curl -s -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-amd64 && \
	chmod +x ./kind && \
	mv ./kind /usr/local/bin/kind && \
	kind version)

check-eksctl:
	@which eksctl  >/dev/null 2>&1 || (echo "eksctl binary not found, installing ..." && \
	curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${OS}_amd64.tar.gz" | tar xz -C /tmp && \
	chmod +x /tmp/eksctl && \
	sudo mv /tmp/eksctl /usr/local/bin && \
	eksctl version)

check-config-dir:
	@echo "Check if config folder exists ...";
	[ -d ${CONFDIR} ] || mkdir ${CONFDIR}

check-repo-dir:
	@echo "Check if config folder exists ...";
	[ ! -d ${REPODIR} ] || rm -rf ${REPODIR}

check-repo-profile-dir:
	@echo "Check if config folder exists ...";
	[ ! -d ${REPODIR}/${PROFILE} ] || rm -rf ${REPODIR}/${PROFILE}

check-platform:
	@echo "Check if PIPLINE_PLATFORM exists ...";
	[ -z "${PIPLINE_PLATFORM}" ] || PLATFORM="${PIPLINE_PLATFORM}"


##@ Cluster
create-cluster:
	@echo "Creating kind management cluster ...";
	kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --config ${BINDIR}/kind-cluster-with-extramounts.yaml --name ${KIND_CLUSTER}

save-kind-cluster-config:
	@echo "Exporting kind management cluster kubeconfig ..."
	kind get kubeconfig --name ${KIND_CLUSTER} > ${CONFDIR}/${KIND_CLUSTER}.kubeconfig

initialise-docker-provider:
	@echo "Initialising docker provider in kind management cluster ..."
	clusterctl init --infrastructure docker --wait-providers || true

generate-manifests-clusterctl:
	@echo "Generating manifests for workload cluster, and applying them ..."
	clusterctl generate cluster ${WORKLOAD_CLUSTER} \
	--flavor development \
	--kubernetes-version v${K8S_VERSION} \
	--control-plane-machine-count=3 \
	--worker-machine-count=3 \
	| kubectl apply -f -

change-kubeconfig:
	@export KUBECONFIG=${CONFDIR}/${KIND_CLUSTER}.kubeconfig

change-eks-kubeconfig:
	@export KUBECONFIG=${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig


create-eks-cluster:
	@echo "Creating eks cluster ..."
	eksctl create cluster --name ${EKS_CLUSTER_NAME} \
		--region ${AWS_REGION} \
		--version ${EKS_K8S_VERSION} \
		--nodegroup-name ${NODEGROUP_NAME} \
		--node-type ${NODE_INSTANCE_TYPE} \
		--nodes ${NUM_OF_NODES} \
		--kubeconfig ${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig

get-eks-kubeconfig:
	@echo "Creating kubeconfig for EKS cluster ..."
	eksctl utils write-kubeconfig --region ${AWS_REGION} --cluster ${EKS_CLUSTER_NAME} --kubeconfig ${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig

delete-eks-cluster:
	@echo "Deleting eks cluster ..."
	eksctl delete cluster --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --wait
##@ kubernetes

upload-profiles-image-to-cluster:
	@echo "Pulling profiles controller from docker hub"
	docker pull weaveworks/profiles-controller:v0.2.0
	@echo "Loading profile controller images into workload cluster nodes"
	kind load docker-image --name ${KIND_CLUSTER} weaveworks/profiles-controller:v0.2.0

install-gitops-on-cluster:
	@echo "Installing WeaveGitops"
	gitops install

install-profiles-on-cluster:
	@echo "Installing profile-controller"
	pctl install --flux-namespace wego-system
##@ catalog


bootstrap-cluster:
	@echo "Adding Profile to repo"
	gitops flux bootstrap github \
	    --owner=${TEST_REPO_USER} \
	    --repository=${TEST_REPO} \
	    --branch=main \
	    --namespace wego-system \
	    --path=clusters/my-cluster \
	    --personal \
	    --read-write-key 

clone-test-repo:
	@echo "Clone test repo"
	git clone git@github.com:${TEST_REPO_USER}/${TEST_REPO}.git ${REPODIR}

commit-test-repo:
	@echo "commiting Profile to repo"
	cd ${REPODIR} && git add . && git commit -m "adding profile" && git push

create-profile-kustomization:
	@echo "Creating Kustomization"
	gitops flux create kustomization ${PROFILE} --export \
	    --path ./${PROFILE} \
	    --interval=1m \
	    --source=GitRepository/wego-system \
	    -n wego-system \
	    --prune=true > ${REPODIR}/clusters/my-cluster/${PROFILE}.yaml

add-profile:
	@echo "Adding Profile to repo"
	cd ${REPODIR} && pctl add --name ${PROFILE} \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./${PROFILE} \
	--profile-branch profile-architecture-redesign


local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing