# External Secrets Profile Installation Guide

- Create namespace for external secrets

```bash
kubectl create ns external-secrets
```

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
kubectl create secret -n external-secrets generic ssh-creds --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts --dry-run=client -o yaml > ssh-creds-data.yaml
kubectl apply -f ssh-creds-data.yaml
kubectl create secret generic ssh-creds-crs-secret --from-file=ssh-creds-data.yaml --type=addons.cluster.x-k8s.io/resource-set
rm ssh-creds-data.yaml
```

- Cluster Resource secret to be bootstrapped in the leaf cluster under bootstrap

```yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha3
kind: ClusterResourceSet
metadata:
  name: ssh-creds
  namespace: default
spec:
  clusterSelector:
    matchLabels:
      secretmanager: aws
  resources:
  - kind: Secret
    name: ssh-creds-crs-secret
```

- Edit values file to the secret ref and path

## Notes on the creating the leaf cluster

- It should have flux bootstrapped on it. using cluster bootstrap config and it should have labels matching the cluster template.

- ClusterResourceSet has cluster selector labels to choose which cluster to be installed on and it should have labels matching the cluster template.

