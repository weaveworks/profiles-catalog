# Profiles for Weave GitOps Enterprise

## weave-gitops-enterprise-eks

```
kubectl create secret -n wego-system docker-registry docker-io-pull-secret --docker-username=stevenfraser --docker-password=
	kubectl label nodes prod-worker wkp-database-volume-node=true
```