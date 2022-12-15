# External Secrets Profile Installation Guide

**Table Of Contents**
- [External Secrets Profile Installation Guide](#external-secrets-profile-installation-guide)
  - [Introduction](#introduction)
  - [Components](#components)
    - [Controller](#controller)
    - [Custom Resource Definitions (CRDs)](#custom-resource-definitions-crds)
      - [SecretStore](#secretstore)
      - [ExternalSecret](#externalsecret)
      - [Note](#note)
    - [CRs](#crs)
  - [Profile Components](#profile-components)
  - [How to install with WGE on Kubernetes Cluster](#how-to-install-with-wge-on-kubernetes-cluster)
    - [Bootstrapping leaf cluster](#bootstrapping-leaf-cluster)
    - [Notes on the creating the leaf cluster](#notes-on-the-creating-the-leaf-cluster)
    - [Using Service Account to authenticate AWS SecretStore](#using-service-account-to-authenticate-aws-secretstore)
      - [How to create Service Account on AWS](#how-to-create-service-account-on-aws)

## Introduction

External Secrets Operator is a Kubernetes operator that integrates external secret management systems like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, Azure Key Vault and many more. The operator reads information from external APIs and automatically injects the values into a Kubernetes Secret.
For more information refer to the docs [here](https://external-secrets.io/v0.6.1/)

## Components

The External Secrets operator consists of the following 3 main parts

### Controller

The External Secrets Operator extends Kubernetes with Custom Resources, which define where secrets live and how to synchronize them. The controller fetches secrets from an external API and creates Kubernetes secrets. If the secret from the external API changes, the controller will reconcile the state in the cluster and update the secrets accordingly.

### Custom Resource Definitions (CRDs)

The operator needs 2 predefined CRDs to be installed on the cluster to be able to operate.

#### SecretStore

The idea behind the SecretStore resource is to separate concerns of authentication/access and the actual Secret and configuration needed for workloads

#### ExternalSecret

An ExternalSecret declares what data to fetch. It has a reference to a SecretStore which knows how to access that data. The controller uses that ExternalSecret as a blueprint to create secrets.


**Note**:

The previous CRDs are namespaced, There is also a global, cluster-wide SecretStore that can be referenced from all namespaces. You can use it to provide a central gateway to your secret provider which are (ClusterSecretStore, ClusterExternalSecret)

### CRs

In order to use the operator you will need to define the SecretStore and the ExternalSecret(s) you will use. You can define one or more and add them to a GitRepository. Then a Kustomization will reference them to be installed on the cluster

## Profile Components 

1- [The HelmChart for External Secrets Operator](Chart.yaml)

2- [Kustomization Reference to secret stores CRs](templates/secret-stores-kustomization.yaml)


## How to install with WGE on Kubernetes Cluster

- Create namespace for external secrets

  ```bash
  kubectl create ns external-secrets
  ```

- Create AWS secret for authenticating the store to be installed on the managment cluster


  ```bash
  kubectl create secret generic awssm-secret --from-literal access-key=$KEY --from-literal secret-access-key=$SECRET -n flux-system
  ```

**Note**: In AWS provided clusters we can use service account/pod identity instead of key/value creds. [here](https://external-secrets.io/v0.6.1/provider/aws-secrets-manager/)

- Git token to access the private repository of secrets

  ```bash
  kubectl create secret -n external-secrets generic ssh-creds --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts
  ```

- Edit values file to the secret ref and path in values.yaml for your secrets repository

### Bootstrapping leaf cluster

- To authenticate the secret store on a leaf cluster with key/secret creds you will need to create a [ClusterResourceSet](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#automatically-install-a-cni-with-clusterresourcesets) having the AWS secret and it will be on the leaf cluster through the [bootstrapping process](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#add-a-cluster-bootstrap-config)

  ```bash
  kubectl create secret generic aws-sm-crs-secret --from-literal access-key=$KEY --from-literal secret-access-key=$SECRET --type=addons.cluster.x-k8s.io/resource-set
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


- To add the ssh creds to flux to be able to access private repository you will need to create a [ClusterResourceSet](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#automatically-install-a-cni-with-clusterresourcesets) having the SSH Creds and it will be on the leaf cluster through the [bootstrapping process](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#add-a-cluster-bootstrap-config)

  ```bash
  kubectl create secret generic ssh-creds-crs-secret --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts --type=addons.cluster.x-k8s.io/resource-set
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

### Notes on the creating the leaf cluster

- It should have flux bootstrapped on it using cluster bootstrap config and it should have labels matching the cluster template.

- ClusterResourceSet has cluster selector labels to choose which cluster to be installed on and it should have labels matching the cluster template.

Full guide to bootstrap leaf cluster with flux with template [here](Bootstrapping-Guide.md)


### Using Service Account to authenticate AWS SecretStore

External Secrets Operator allows to use service account in order to authenticate the SecretStore that's using AWS Secrets Manger.
This methods doesn't require to provide AWS Creds (Key, Secret) instead only uses the service account created on AWS

#### How to create Service Account on AWS

1- Create IAM Policy on AWS console for secrets managment

  **Example**

  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "secretsmanager:GetResourcePolicy",
                  "secretsmanager:GetSecretValue",
                  "secretsmanager:DescribeSecret",
                  "secretsmanager:ListSecretVersionIds"
              ],
              "Resource": [
                  "arn:aws:secretsmanager:<region>:<account-id>:secret:<secret-path>"
              ]
          }
      ]
  }
  ```
  region: AWS cluster region -> Example: `eu-north-1`
  account-id: AWS Account ID -> Example: `123123123412`
  secret-path: Path of the secret in AWS secret manager that this service account will have access to -> Example `/dev/*`

2- Add Identity Provider on AWS console with the URL of the cluster OIDC

  Get cluster OIDC from:

  ```bash
  aws eks describe-cluster --name <cluster-name --query "cluster.identity.oidc.issuer" --output text --region <cluster-region>
  ```

  Also Add audience to `sts.amazonaws.com`

3- Add Role on AWS console with the following Trust Relationship and attach the previous policy

  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "Federated": "arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<cluster-oidc-id>" # aws-arn
              },
              "Action": "sts:AssumeRoleWithWebIdentity",
              "Condition": {
                  "StringEquals": {
                      "oidc.eks.<region>.amazonaws.com/id/<cluster-oidc-id>:aud": "sts.amazonaws.com",
                      "oidc.eks.<region>.amazonaws.com/id/<cluster-oidc-id>:sub": "system:serviceaccount:<service-account-namespace>:<service-account-name>"
                  }
              }
          }
      ]
  }
  ```

4- Add Service Account Resource next to the secret store

  **Example Service Account**

  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: <service-account-name>
    namespace: <service-account-namespace>
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::<account-id>:role/<role-name>"
  ```

  **Example Secret Store**

  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: SecretStore
  metadata:
    name: <secret-store-name>
    namespace: <secret-store-namespace>
  spec:
    provider:
      aws:
        service: SecretsManager
        region: <aws-region>
        auth:
          jwt:
            serviceAccountRef:
              name: <service-account-name>
  ```