# Profiles Catalog

Profiles Catalog contains a curated list of profiles for various use cases. A profile is an individual package of Kubernetes components. 

Need more information about profiles? Please visit [Profiles Documentation](https://profiles.dev/docs/intro).

## Installation
Pre-requisites: follow [Environment Setup](https://profiles.dev/docs/tutorial-basics/setup) to complete installation of Flux and Profile Catalog Source Controller.

Add Profiles Catalog:
```
$ kubectl apply -f source.yaml
# allow a few moments. the more profiles/tags, the more time the catalog manager
# will need to discover them all
```

and list available catalogued profiles:
```
$ pctl get --catalog   
```

To add from a profile catalog entry: 
```
pctl --catalog-url https://github.com/weaveworks/profiles-catalog add --name <profile-name> --namespace default --profile-branch main --config-map configmap-name weaveworks-profiles-catalog/<PROFILE>[/<VERSION>]
```
