#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -e
set -u

set -o pipefail

unset KUBECONFIG

WEGO_VERSION="0.2.5"
PCTL_VERSION="0.8.0"

WORKLOAD_CLUSTER=testing
KIND_CLUSTER=mgmt

#Install WeaveGitops:
# - check if installed, if not install from GH release:
if [[ ! -x $(which wego) ]]; then
    echo "wego binary not found, installing ..."
    curl -L "https://github.com/weaveworks/weave-gitops/releases/download/v${WEGO_VERSION}/wego-$(uname)-$(uname -m)" -o wego
    chmod +x wego
    sudo mv ./wego /usr/local/bin/wego
    wego version
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

echo "Creating kind management cluster ..."
kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --config kind-cluster-with-extramounts.yaml --name ${KIND_CLUSTER}

echo "Exporting kind management cluster kubeconfig ..."
kind get kubeconfig --name ${KIND_CLUSTER} > ${KIND_CLUSTER}.kubeconfig

echo "Initialising docker provider in kind management cluster ..."
clusterctl init --infrastructure docker --wait-providers || true

echo "Generating manifests for workload cluster, and applying them ..."
clusterctl generate cluster ${WORKLOAD_CLUSTER} \
  --flavor development \
  --kubernetes-version v1.21.1 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  | kubectl apply -f -

READY=false
set +e
echo "Checking whether workload cluster in ready state..."
until [[ $READY == "true" ]]; do
    clusterctl describe cluster ${WORKLOAD_CLUSTER} 2>&1 | grep -i "/${WORKLOAD_CLUSTER}" | grep True
    if [ $? == 0 ]; then
        READY=true
    else
        echo "Cluster still pending.. waiting"
        sleep 3
    fi
    clusterctl describe cluster ${WORKLOAD_CLUSTER} 2>&1 | grep -i "ClusterInfrastructure" | grep True
    if [ $? == 0 ]; then
        READY=true
    else
        echo "Cluster still pending.. waiting"
        sleep 3
    fi
done
set -e

echo "Currently running machines:"
kubectl get machines

READY=false
set +e
echo "Checking whether machines in workload cluster in RUNNING state..."
until [[ $READY == "true" ]]; do
    kubectl get machines -o jsonpath='{.items[].status.phase}' | grep Running
    if [ $? == 0 ]; then
        READY=true
    else
        echo "Cluster still pending.. waiting"
        sleep 3
    fi
done
set -e

clusterctl get kubeconfig ${WORKLOAD_CLUSTER} > ${WORKLOAD_CLUSTER}.kubeconfig

sed -i -e "s/certificate-authority-data:.*/insecure-skip-tls-verify: true/g" ./${WORKLOAD_CLUSTER}.kubeconfig
sed -i -e "s/server:.*/server: https:\/\/$(docker port ${WORKLOAD_CLUSTER}-lb 6443/tcp | sed "s/0.0.0.0/127.0.0.1/")/g" ./${WORKLOAD_CLUSTER}.kubeconfig

#kubectl --kubeconfig=./${WORKLOAD_CLUSTER}.kubeconfig apply -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml

echo "Installing Cilium CNI, via Helm"
helm repo add cilium https://helm.cilium.io/
helm status --kubeconfig=./${WORKLOAD_CLUSTER}.kubeconfig -n kube-system cilium || \
    helm install cilium cilium/cilium --version 1.9.10 \
        --kubeconfig=./${WORKLOAD_CLUSTER}.kubeconfig \
        --namespace kube-system \
        --set nodeinit.enabled=true \
        --set kubeProxyReplacement=partial \
        --set hostServices.enabled=false \
        --set externalIPs.enabled=true \
        --set nodePort.enabled=true \
        --set hostPort.enabled=true \
        --set bpf.masquerade=false \
        --set image.pullPolicy=IfNotPresent \
        --set ipam.mode=kubernetes \
        --wait

export KUBECONFIG=./${WORKLOAD_CLUSTER}.kubeconfig

echo "Pulling profiles controller from docker hub"
docker pull weaveworks/profiles-controller:v0.2.0

echo "Loading profile controller images into workload cluster nodes"
kind load docker-image --name ${WORKLOAD_CLUSTER} weaveworks/profiles-controller:v0.2.0

echo "Installing WeaveGitops"
wego gitops install

echo "Installing profile-controller"
pctl install --flux-namespace wego-system