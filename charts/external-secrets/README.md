# External Secrets Profile Installation Guide

## Introduction

External Secrets Operator is a Kubernetes operator that integrates external secret management systems like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, Azure Key Vault and many more. The operator reads information from external APIs and automatically injects the values into a Kubernetes Secret.
For more information refer to the docs [here](https://external-secrets.io/v0.6.1/)

## Components

The External Secrets operator consists of 3 main parts as the following

### Controller

The External Secrets Operator extends Kubernetes with Custom Resources, which define where secrets live and how to synchronize them. The controller fetches secrets from an external API and creates Kubernetes secrets. If the secret from the external API changes, the controller will reconcile the state in the cluster and update the secrets accordingly.

### Custom Resource Definitions (CRDs)

The operator needs 2 predefined CRDs to be installed on the cluster to be able to operate.

#### SecretStore

The idea behind the SecretStore resource is to separate concerns of authentication/access and the actual Secret and configuration needed for workloads

#### ExternalSecret

An ExternalSecret declares what data to fetch. It has a reference to a SecretStore which knows how to access that data. The controller uses that ExternalSecret as a blueprint to create secrets.

#### Note

The previous CRDs are namespaced, There is also a global, cluster-wide SecretStore that can be referenced from all namespaces. You can use it to provide a central gateway to your secret provider which are (ClusterSecretStore, ClusterExternalSecret)

### CRs

In order to use the operator you will need to define the SecretStore and the ExternalSecret(s) you will use. You can define one or more and add them to a GitRepository. Then a Kustomization will reference them to be installed on the cluster

## Profile Components 

1- [The HelmChart for External Secrets Operator](charts/external-secrets/Chart.yaml)

2- [Kustomization Reference to the CRs](charts/external-secrets/templates/secrets.yaml)


## How to install with WGE on Kubernetes Cluster

- Create namespace for external secrets

```bash
kubectl create ns external-secrets
```

- Create AWS secret for authenticating the store to be installed on the managment cluster

  **Note**: To authenticate the secret store on a leaf cluster with key/secret creds you will need to create a [ClusterResourceSet](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#automatically-install-a-cni-with-clusterresourcesets) having the AWS secret and it will be on the leaf cluster through the [bootstrapping process](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#add-a-cluster-bootstrap-config)

```bash
kubectl create secret generic awssm-secret --from-literal access-key=$KEY --from-literal secret-access-key=$SECRET -n flux-system --dry-run=client -o yaml > aws-sm-crs-data.yaml

kubectl apply -f aws-sm-crs-data.yaml

kubectl create secret generic aws-sm-crs-secret --from-file=aws-sm-crs-data.yaml --type=addons.cluster.x-k8s.io/resource-set

rm aws-sm-crs-data.yaml
```

- Cluster Resource secret to be bootstrapped in the leaf cluster under bootstrap. Make sure to add the cluster selector label `secretmanager: aws` under GitOpsCluster in the cluster template

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

  **Note**: To add the ssh creds to flux to be able to access private repository you will need to create a [ClusterResourceSet](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#automatically-install-a-cni-with-clusterresourcesets) having the SSH Creds and it will be on the leaf cluster through the [bootstrapping process](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#add-a-cluster-bootstrap-config)

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

- Edit values file to the secret ref and path in values.yaml for your secrets repository

## Notes on the creating the leaf cluster

- It should have flux bootstrapped on it. using cluster bootstrap config and it should have labels matching the cluster template.

- ClusterResourceSet has cluster selector labels to choose which cluster to be installed on and it should have labels matching the cluster template.

Full guide to bootstrap leaf cluster with flux with template [here](https://www.notion.so/weaveworks/Guide-How-To-Secrets-Management-with-flux-ad91b52e3ba5415c97e2235ae394bf4f)