# Profiles for Weave GitOps Enterprise

## weave-gitops-enterprise-eks


### Install weave-gitops-enterprise-eks Profile
Add Docker Secret for private images
```
kubectl create secret docker-registry docker-io-pull-secret --docker-username=stevenfraser --docker-password=
```

`Optional` Add git provider credentials for github for cluster provising
```
kubectl create secret generic git-provider-credentials -n wego-system  --from-literal="GIT_PROVIDER_TOKEN=$GITHUB_TOKEN"
```

Label database for SQL file
```
NODE=$(kubectl get nodes -o json | jq --raw-output '.items[0].status.addresses[] | select(.type=="InternalDNS") | .address') && kubectl label nodes $NODE wkp-database-volume-node=true
```

Install profile
```
pctl add --name weave-gitops-enterprise-eks \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./weave-gitops-enterprise-eks \
	--profile-branch main
```

Commit profile to repo
```
git add . && git commit -m "adding profile" && git push
```

### Set specific variables for the demo/customer (After installed)

Set Hostname to set agent configuration to report into mgmt-cluster
```
export INGRESS=$(kubectl get svc -o json --field-selector=metadata.name=mccp-chart-nats-client -A | jq --raw-output -r '.items[].status.loadBalancer.ingress | to_entries[].value.hostname') 

export CONFIG_MAP_FILE="${PWD}/weave-gitops-enterprise-eks/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s/mccp-chart-nats-client/$INGRESS/g" $CONFIG_MAP_FILE

Set CAPI repo location
```
export CAPI_REPO=https://github.com/ww-customer-test/profile-test-repo

export CONFIG_MAP_FILE="${PWD}/weave-gitops-enterprise-eks/artifacts/mccp-chart/helm-chart/ConfigMap.yaml"

sed -i '' "s#https://github.com/weaveworks/my-cluster-repo#$CAPI_REPO#g" $CONFIG_MAP_FILE
```

```
git add . && git commit -m "configuring ingress for agents and capi repo" && git push
```

Reconcile HelmRelease
```
flux reconcile helmrelease weave-gitops-enterprise-eks-mccp-chart -n default
```


