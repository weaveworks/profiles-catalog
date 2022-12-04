# External Secrets Profile Installation Guide

- AWS secret for authenticating the store to be installed on the managment cluster
- Cluster Resource secret to be bootstrapped in the leaf cluster

```bash
kubectl create secret generic awssm-secret --from-literal access-key=$KEY --from-literal secret-access-key=$SECRET  -n flux-system --dry-run=client -o yaml > aws-sm-crs-data.yaml
kubectl apply -f aws-sm-crs-data.yaml
kubectl create secret generic aws-sm-crs-secret --from-file=aws-sm-crs-data.yaml --type=addons.cluster.x-k8s.io/resource-set
rm aws-sm-crs-data.yaml
```

- Git token to access the private repository of secrets

```bash
kubectl create secret -n external-secrets generic my-pat --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts
```

- Edit values file to the secret repo and path