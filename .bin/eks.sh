#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -eu
set -o pipefail

unset KUBECONFIG

GITOPS_VERSION="0.3.0"
PCTL_VERSION="0.11.0"

EKS_CLUSTER_NAME="profiles-cluster"
AWS_REGION="us-west-1"
NODEGROUP_NAME="ng-1"
NODE_INSTANCE_TYPE="m5.large"
NUM_OF_NODES="2"
K8S_VERSION="1.21"

CONFDIR="${PWD}/.conf"

#Install WeaveGitops:
# - check if installed, if not install from GH release:
if [[ ! -x $(which gitops) ]]; then
    echo "gitops binary not found, installing ..."
    curl -L "https://github.com/weaveworks/weave-gitops/releases/download/v${GITOPS_VERSION}/gitops-$(uname)-$(uname -m)" -o gitops
    chmod +x gitops
    sudo mv ./gitops /usr/local/bin/gitops
    gitops version
fi

#Install ProfileCTL:
# - check if installed, if not install from GH release:
if [[ ! -x $(which pctl) ]]; then
    echo "pctl binary not found, installing ..."
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    wget "https://github.com/weaveworks/pctl/releases/download/v${PCTL_VERSION}/pctl_${OS}_amd64.tar.gz"
    tar xvfz pctl_${OS}_amd64.tar.gz
    sudo mv ./pctl /usr/local/bin/pctl
    pctl --version
fi

#Install eksctl:
# - check if installed, if not install from GH release:
if [[ ! -x $(which eksctl) ]]; then
    echo "eksctl binary not found, installing ..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    eksctl version
fi

echo "Check if config folder exists ..."
[[ -d ${CONFDIR} ]] || mkdir ${CONFDIR}

echo "Check if cluster exists ..."
if ! eksctl get clusters --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}; then
    echo "Creating EKS cluster ..."
    eksctl create cluster --name ${EKS_CLUSTER_NAME} \
      --region ${AWS_REGION} \
      --version ${K8S_VERSION} \
      --nodegroup-name ${NODEGROUP_NAME} \
      --node-type ${NODE_INSTANCE_TYPE} \
      --nodes ${NUM_OF_NODES} \
      --kubeconfig ${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig
else
    echo "Cluster already exists. Just getting kubeconfig ..."
    eksctl utils write-kubeconfig --region ${AWS_REGION} --cluster ${EKS_CLUSTER_NAME} --kubeconfig ${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig
fi

export KUBECONFIG=${CONFDIR}/${EKS_CLUSTER_NAME}.kubeconfig

echo "Installing Weave Gitops ..."
gitops install

echo "Installing profile-controller ..."
pctl install --flux-namespace wego-system