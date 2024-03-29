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
GCLOUD_VERSION=360.0.0

OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"
REPODIR="${PWD}/.repo"

KIND_CLUSTER=testing

EKS_CLUSTER_NAME?="profiles-cluster"
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
PROFILE?=gitops-enterprise-mgmt-kind

TEST_REPO_USER?=weaveworks
TEST_REPO?=profiles-catalog-test
TEST_REPO_BRANCH?=testing
CATALOG_REPO_URL=git@github.com:weaveworks/profiles-catalog.git

PROFILE_VERSION_ANNOTATION="profiles.weave.works/version"

BUILD_NUM?=0

INFRASTRUCTURE?="kind"

DOCKERHUB_USERNAME?=tomhuang12
DOCKERHUB_ACCESS_TOKEN?=secret
##@ Flows


##@ with-clusterctl: check-requirements create-cluster save-kind-cluster-config initialise-docker-provider generate-manifests-clusterctl


eks-e2e: deploy-profile-eks

kind-e2e: deploy-profile-kind

gke-e2e: deploy-profile-gke

deploy-profile-eks: check-requirements check-eksctl check-awscli create-cluster get-eks-kubeconfig  install-profile-and-sync delete-cluster

deploy-profile-kind: check-requirements check-kind create-cluster check-config-dir save-kind-cluster-config upload-profiles-image-to-cluster install-profile-and-sync

deploy-profile-gke: check-requirements check-gcloud create-cluster get-gke-kubeconfig install-profile-and-sync delete-cluster

PROFILE_VERSION_ANNOTATION="profiles.weave.works/version"

##@ This really needs to be taken out of make into bash for the long term.
##@ It seems like this is forcing make to do something it was not designed for.
check-profile-versions:
	@for f in ${PROFILE_FILES}; do  \
	git show origin/main:$${f} >  /tmp/tmp-profile.yaml 2>&1 && \
	( yq e '.metadata.annotations.${PROFILE_VERSION_ANNOTATION}' ${PWD}/$${f} | cat > /tmp/tmp-new ) && \
	( yq e '.metadata.annotations.${PROFILE_VERSION_ANNOTATION}' /tmp/tmp-profile.yaml | cat > /tmp/tmp-old ) && \
	( yq e '.metadata.name' /tmp/tmp-profile.yaml | cat > /tmp/tmp-name ) && \
	git diff --quiet HEAD origin/main -- $$f || \
		(  diff /tmp/tmp-new /tmp/tmp-old \
		&& pkill make || \
		echo "$(cat /tmp/tmp-new) $(cat /tmp/tmp-old) Not equal" ) ; done

release:
	@for f in ${PROFILE_FILES}; do  \
		 yq e '.metadata.annotations.${PROFILE_VERSION_ANNOTATION}' ${PWD}/$${f} | cat > /tmp/tmp-version ; \
		 yq e '.metadata.name' ${PWD}/$${f} | cat > /tmp/tmp-name ; \
		echo "null" | cat > /tmp/null-value ; \
		paste -d / /tmp/tmp-name /tmp/tmp-version > /tmp/tmp-release ; \
		diff /tmp/null-value /tmp/tmp-version || cat /tmp/tmp-release | xargs -I {} gh release create --notes "test" {} || true; done
		



##@ Post Kubernetes creation with valid KUBECONFIG set it installs gitops and profiles, boostraps cluster, installs profile, and syncs
##@ TODO: Clear current profile is it's there
install-profile-and-sync: install-gitops-on-cluster install-profiles-on-cluster bootstrap-cluster check-repo-dir clone-test-repo create-profile-kustomization add-profile commit-profile reconcile-wego-system test-single-profile delete-branch

remove-all-installed-kustomization:
	@for f in $(shell ls ${PWD}); do [ ! -f ${REPODIR}/clusters/my-cluster/$${f}.yaml ] || rm ${REPODIR}/clusters/my-cluster/$${f}.yaml; done

remove-all-installed-profiles:
	@for f in $(shell ls ${PWD}); do [ ! -d ${REPODIR}/$${f} ] || rm -rf ${REPODIR}/$${f}; done

##@ validate-configuration


##@ Requirements
check-requirements: check-gitops check-clusterctl


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

check-awscli:
	@which aws  >/dev/null 2>&1 || (echo "aws binary not found, installing ..." && \
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
	unzip awscliv2.zip && \
	sudo ./aws/install && \
	aws --version)

check-gcloud:
	@which kind  >/dev/null 2>&1 || (echo "gcloud binary not found, installing ..." && \	
	curl --silent --location "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-${OS}-x86_64.tar.gz" | tar xz -C /tmp && \
	./tmp/google-cloud-sdk/install.sh -q && \
	gcloud version)

check-config-dir:
	@echo "Check if config folder exists ...";
	[ -d ${CONFDIR} ] || mkdir ${CONFDIR}

check-repo-dir:
	@echo "Check if repository folder exists ...";
	[ ! -d ${REPODIR} ] || rm -rf ${REPODIR}

reconcile-wego-system:
	@echo "gitops wego-system";
	gitops flux reconcile source git wego-system -n wego-system

##@ Cluster
create-cluster:
	@if [ ${INFRASTRUCTURE} = "kind" ]; then\
		echo "Creating kind management cluster ...";
		kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --config ${BINDIR}/kind-cluster-with-extramounts.yaml --name ${KIND_CLUSTER}
	elif [ ${INFRASTRUCTURE} = "eks" ]; then\
		echo "Creating eks cluster ..."
		eksctl delete cluster --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --wait || eksctl create cluster --name ${EKS_CLUSTER_NAME} \
			--region ${AWS_REGION} \
			--version ${EKS_K8S_VERSION} \
			--nodegroup-name ${NODEGROUP_NAME} \
			--node-type ${NODE_INSTANCE_TYPE} \
			--nodes ${NUM_OF_NODES} \
			--kubeconfig ${CONFDIR}/eks-cluster.kubeconfig
	elif [ ${INFRASTRUCTURE} = "gke" ]; then\
		echo "Creating gke cluster ..."
		gcloud container clusters create ${GKE_CLUSTER_NAME} --region ${GCP_REGION} -m ${GCP_MACHINE_TYPE}  --num-nodes=${GCP_NUM_NODES} --project ${GCP_PROJECT_NAME}
	fi

delete-cluster: 
	@if [ ${INFRASTRUCTURE} = "kind" ]; then\
		echo "Deleting kind cluster ..."
		kind delete cluster --name ${KIND_CLUSTER}
	elif [ ${INFRASTRUCTURE} = "eks" ]; then\
		echo "Deleting eks cluster ..."
		eksctl delete cluster --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --wait || \
		aws cloudformation delete-stack --region ${AWS_REGION} --stack-name eksctl-${EKS_CLUSTER_NAME}-cluster
	elif [ ${INFRASTRUCTURE} = "gke" ]; then\
		echo "Deleting gke cluster ..."
		gcloud container clusters delete ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_NAME} -q
	fi

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

get-eks-kubeconfig:
	@echo "Creating kubeconfig for EKS cluster ..."
	eksctl utils write-kubeconfig --region ${AWS_REGION} --cluster ${EKS_CLUSTER_NAME} --kubeconfig ${CONFDIR}/eks-cluster.kubeconfig

get-gke-kubeconfig:
	@echo "Creating kubeconfig for GKE cluster ..."
	gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_NAME}

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
	@if [ "${PIPELINE}" = "1" ]; then\
        echo "bootstrapping via git" && \
			kubectl create secret generic -n wego-system flux-system \
			--from-file=identity=/tmp/git-keys/${TEST_REPO_USER}-${TEST_REPO} \
			--from-file=identity.pub=/tmp/git-keys/${TEST_REPO_USER}-${TEST_REPO}.pub && \
			gitops flux bootstrap git -s \
			--url=ssh://git@github.com/${TEST_REPO_USER}/${TEST_REPO}.git \
			--namespace wego-system \
			--path=clusters/my-cluster \
			--branch ${TEST_REPO_BRANCH} \
			--private-key-file=/tmp/git-keys/${TEST_REPO_USER}-${TEST_REPO}; \
	else \
        echo "bootstrapping via github" && \
		gitops flux bootstrap github \
		--owner=${TEST_REPO_USER} \
		--repository=${TEST_REPO} \
		--namespace wego-system \
		--path=clusters/my-cluster \
		--personal \
		--branch ${TEST_REPO_BRANCH} \
		--read-write-key; \
    fi

clone-test-repo:
	@echo "Clone test repo"SHELL: /bin/bash
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

provision-capi-cluster: check-clusterctl create-capi-cluster

create-capi-cluster:
	gcloud container clusters create ${GKE_CLUSTER_NAME} --region ${GCP_REGION} -m ${GCP_MACHINE_TYPE}  --num-nodes=${GCP_NUM_NODES} --project ${GCP_PROJECT_NAME}

check-clusterctl:
	@which clusterctl >/dev/null 2>&1 || (echo "clusterctl binary not found, installing ..." && \
	curl -s -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-${OS}-amd64" -o clusterctl && \
	chmod +x clusterctl && \
	sudo mv ./clusterctl /usr/local/bin/clusterctl && \
	clusterctl version)
	git clone -b ${TEST_REPO_BRANCH} git@github.com:${TEST_REPO_USER}/${TEST_REPO}.git ${REPODIR}


commit-clean:
	@echo "Commiting cleaning to repo ..."
	cd ${REPODIR} && git add . && ( git commit -m "cleaning profile" | git push  || true )
	
commit-profile:
	@echo "Committing profile to repo ..."
	cd ${REPODIR} && git add . && git commit -m "adding profile" && git push 

delete-branch:
	@echo "Deleting testing branch ..."
	cd ${REPODIR} && git push origin --delete ${TEST_REPO_BRANCH}

create-profile-kustomization:
	@echo "Creating Kustomization"
	gitops flux create kustomization ${PROFILE} --export \
	    --path ./${PROFILE} \
	    --interval=1m \
	    --source=GitRepository/wego-system \
	    -n wego-system \
	    --prune=true > ${REPODIR}/clusters/my-cluster/${PROFILE}.yaml

add-profile:
	@echo "Creating docker hub registry secret and labeling nodes ..."
	kubectl create secret docker-registry docker-io-pull-secret --docker-username=${DOCKERHUB_USERNAME} --docker-password=${DOCKERHUB_ACCESS_TOKEN}
	kubectl label nodes $(shell kubectl get nodes -o jsonpath='{.items[0].metadata.name}') wkp-database-volume-node=true
	echo "Adding pctl Profile to repo ..."
	git branch --show-current > /tmp/branch && \
	cd ${REPODIR} && \
	cat /tmp/branch | \
	xargs -I {} \
	pctl add --name ${PROFILE} \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./${PROFILE} \
	--profile-branch {}


local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing


##@ Profile tests flow
test-single-profile:
	@if [ ${INFRASTRUCTURE} = "kind" ]; then\
		export KUBECONFIG=${CONFDIR}/${KIND_CLUSTER}.kubeconfig
	elif [ ${INFRASTRUCTURE} = "eks" ]; then\
		export KUBECONFIG=${CONFDIR}/eks-cluster.kubeconfig
	elif [ ${INFRASTRUCTURE} = "gke" ]; then\
		gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_NAME}
		export KUBECONFIG=$${HOME}/.kube/config
	fi
	cd tests && go test -timeout 20m -args -profilename=${PROFILE}

##@ Update Helm chart versions for profile references
update-chart-versions: check-repo-dir clone-profiles-repo bump-versions commit-versions

clone-profiles-repo:
	@echo "Clone profiles repo ..."
	git clone -b main git@github.com:weaveworks/profiles-catalog.git ${REPODIR} 

commit-versions:
	@echo "Committing version changes to repo"
	cd ${REPODIR} && git add . && git checkout -b bump-versions-${BUILD_NUM} && git commit -m "bump versions" && git push --set-upstream origin bump-versions-${BUILD_NUM}
