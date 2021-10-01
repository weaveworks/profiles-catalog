# Profiles for Weave GitOps Enterprise

## weave-gitops-enterprise-eks

```
kubectl create secret docker-registry docker-io-pull-secret --docker-username=stevenfraser --docker-password=
kubectl label nodes ip-192-168-38-251.us-west-1.compute.internal wkp-database-volume-node=true


pctl add --name weave-gitops-enterprise-eks \
	--profile-repo-url git@github.com:weaveworks/profiles-catalog.git \
	--git-repository wego-system/wego-system \
	--profile-path ./weave-gitops-enterprise-eks \
	--profile-branch main

```