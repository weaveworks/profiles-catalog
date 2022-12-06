# External Secrets Profile Installation Guide

- AWS secret for authenticating the store to be installed on the managment cluster

```bash
kubectl create secret generic awssm-secret --from-literal access-key=$KEY --from-literal secret-access-key=$SECRET -n flux-system --dry-run=client -o yaml > aws-sm-crs-data.yaml
kubectl apply -f aws-sm-crs-data.yaml
kubectl create secret generic aws-sm-crs-secret --from-file=aws-sm-crs-data.yaml --type=addons.cluster.x-k8s.io/resource-set
rm aws-sm-crs-data.yaml
```

- Cluster Resource secret to be bootstrapped in the leaf cluster under bootstrap

```yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha3
kind: ClusterResourceSet
metadata:
  name: awssm-crs
  namespace: default
spec:
  clusterSelector:
    matchLabels:
      secretmanager: aws
  resources:
  - kind: Secret
    name: aws-sm-crs-secret
```

- Git token to access the private repository of secrets

```bash
kubectl create secret -n external-secrets generic my-pat --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts --dry-run=client -o yaml > my-pat-data.yaml
kubectl apply -f my-pat-data.yaml
kubectl create secret generic my-pat-crs-secret --from-file=my-pat-data.yaml --type=addons.cluster.x-k8s.io/resource-set -n external-secrets
rm my-pat-data.yaml
```

- Cluster Resource secret to be bootstrapped in the leaf cluster under bootstrap

```yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha3
kind: ClusterResourceSet
metadata:
  name: my-pat
  namespace: external-secrets
spec:
  clusterSelector:
    matchLabels:
      secretmanager: aws
  resources:
  - kind: Secret
    name: my-pat-crs-secret
```

- Edit values file to the secret ref and path