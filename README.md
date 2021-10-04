# Profiles for Weave GitOps Enterprise

## weave-gitops-enterprise-eks

### Repositories

Profiles Catalog: https://github.com/weaveworks/profiles-catalog/tree/demo-profile  
Profiles Test Repo: https://github.com/ww-customer-test/profile-test-repo

### Prerequisites

**Set up Weaveworks AWS SSO**:
https://www.notion.so/weaveworks/Accessing-AWS-Resources-600faa584fec4c6ba5b0f2ef27be309e

**If the cluster doesn't exist, provision EKS Cluster**
```
# Run in Profile Catalog repository
./.bin/eks.sh
```

**If the cluster already exists, get kubeconfig**
```
# Run in Profile Catalog repository
make get-eks-kubeconfig
```

**If Flux isn't set up yet, bootstrap Flux**
```
gitops flux bootstrap github \
    --owner=ww-customer-test
    --repository=profile-test-repo
    --path=clusters/my-cluster
```

### Install weave-gitops-enterprise-eks Profile
**Add Docker Secret for private images**
```
kubectl create secret docker-registry docker-io-pull-secret --docker-username=stevenfraser --docker-password=
```

**Optional: Add git provider credentials for github for cluster provising**
```
kubectl create secret generic git-provider-credentials -n wego-system  --from-literal="GIT_PROVIDER_TOKEN=$GITHUB_TOKEN"
```

**Label database for SQL file**
```
NODE=$(kubectl get nodes -o json | jq --raw-output '.items[0].status.addresses[] | select(.type=="InternalDNS") | .address') && kubectl label nodes $NODE wkp-database-volume-node=true
```

**Install profile**
```
pctl add --name weave-gitops-enterprise-eks \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./weave-gitops-enterprise-eks \
	--profile-branch main
```

**Commit profile to repo**
```
git add . && git commit -m "adding profile" && git push
```

### Set specific variables for the demo/customer (After installed)

**Set Hostname to set agent configuration to report into mgmt-cluster**
```
export INGRESS=$(kubectl get service istio-ingressgateway -n istio-system -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}') 

export CONFIG_MAP_FILE="${PWD}/weave-gitops-enterprise-eks/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s/mccp-chart-nats-client/$INGRESS/g" $CONFIG_MAP_FILE
```

**Set CAPI repo location**
```
export CAPI_REPO=https://github.com/ww-customer-test/profile-test-repo

export CONFIG_MAP_FILE="${PWD}/weave-gitops-enterprise-eks/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s#https://github.com/weaveworks/my-cluster-repo#$CAPI_REPO#g" $CONFIG_MAP_FILE
```

```
git add . && git commit -m "configuring ingress for agents and capi repo" && git push
```

**Reconcile HelmRelease**
```
flux reconcile helmrelease weave-gitops-enterprise-eks-mccp-chart -n default
```

**Get Load Balancer URL**  
Once the profile is fully installed and resources are provisioned, get istio-ingressgateway's load balancer URL.
```
kubectl get service istio-ingressgateway -n istio-system -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Console links**

Weave GitOps Enterprise Console: `<load-balancer-url>`  
Grafana Console: `<load-balancer-url>/grafana/login`  
Weave Scope Console: `<load-balancer-url>/scope/`  

### EKS CAPI Provider Set Up
```
clusterawsadm bootstrap iam create-cloudformation-stack
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
export EXP_MACHINE_POOL=true
clusterctl init --infrastructure aws
```
Reference: https://cluster-api-aws.sigs.k8s.io/getting-started.html#initialize-the-management-cluster

### Clean-up Profile
```
# Run in Profile Test Repo
./.bin/cleanup.sh
```
The script above will create a PR. Go to https://github.com/ww-customer-test/profile-test-repo and merge the PR to clean-up resources.

### Delete Cluster
```
# Run in Profile Catalog repository
make delete-eks-cluster
```


