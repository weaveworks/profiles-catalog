# Profiles for Weave GitOps Enterprise

## weave-gitops-enterprise-eks

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
kubectl label nodes ip-192-168-38-251.us-west-1.compute.internal wkp-database-volume-node=true
```

Install profile
```
pctl add --name weave-gitops-enterprise-eks \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./weave-gitops-enterprise-eks \
	--profile-branch main
```

Get hostname to set agent configuration
```
kubectl -n istio-system get svc istio-ingressgateway -o json | jq -r '.status.loadBalancer.ingress | to_entries[].value.hostname'

```