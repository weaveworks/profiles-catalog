# Profiles for Weave GitOps Enterprise

## gitops-enterprise-mgmt-eks

### Prerequisites

**Set up Weaveworks AWS SSO**:
https://www.notion.so/weaveworks/Accessing-AWS-Resources-600faa584fec4c6ba5b0f2ef27be309e

**If the cluster doesn't exist, provision EKS Cluster**
```
./.bin/eks.sh
```

### Install gitops-enterprise-mgmt-eks Profile
**Add Docker Secret for private images**
```
kubectl create secret docker-registry docker-io-pull-secret --docker-username=stevenfraser --docker-password=
```

**Optional: Add git provider credentials for github for cluster provising**
```
kubectl create secret generic git-provider-credentials --from-literal="GIT_PROVIDER_TOKEN=$GITHUB_TOKEN"
```

**Label database for SQL file**
```
NODE=$(kubectl get nodes -o json | jq --raw-output '.items[0].status.addresses[] | select(.type=="InternalDNS") | .address') && kubectl label nodes $NODE wkp-database-volume-node=true
```

**Install profile**
```
make install-profile-and-sync
```

**Commit profile to repo**
```
git add . && git commit -m "adding profile" && git push
```

### Set specific variables for the demo/customer (After installed)

**Set Hostname to set agent configuration to report into mgmt-cluster**
```
export INGRESS=$(kubectl get service istio-ingressgateway -n istio-system -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}') 

export CONFIG_MAP_FILE="${PWD}/gitops-enterprise-mgmt-base/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s/mccp-chart-nats-client/$INGRESS/g" $CONFIG_MAP_FILE
```

**Set CAPI repo location**
```
export CAPI_REPO=https://github.com/ww-customer-test/profile-test-repo

export CONFIG_MAP_FILE="${PWD}/gitops-enterprise-mgmt-base/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s#https://github.com/weaveworks/my-cluster-repo#$CAPI_REPO#g" $CONFIG_MAP_FILE
```

```
git add . && git commit -m "configuring ingress for agents and capi repo" && git push
```

**Reconcile HelmRelease**
```
flux reconcile helmrelease gitops-enterprise-mgmt-eks-mccp-chart -n default
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
Alert Manager: `<load-balancer-url>/alertmanager/`  

### EKS CAPI Provider Set Up
```
clusterawsadm bootstrap iam create-cloudformation-stack
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
export EXP_MACHINE_POOL=true
clusterctl init --infrastructure aws
```
Reference: https://cluster-api-aws.sigs.k8s.io/getting-started.html#initialize-the-management-cluster

### Delete Cluster
```
# Run in Profile Catalog repository
make delete-eks-cluster
```


