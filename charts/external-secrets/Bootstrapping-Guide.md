# [Guide][How-To] Secrets Management with flux

# Goal

Bootstrapping external secret operator with flux

## Installation problem

In Flux, we can't have dependencies between Flux Kustomization and HelmRelease, so we install `external-secrets-operator` through a `HelmRelease` and the `Secrets` CRs (`SecretStore`, `ExternalSecret, ..`) through a Flux Kustomization.

Both controllers manage the resources independently, at different moments, with no possibility to wait each other. This means that we have a wonderful race condition where sometimes the CRs (`SecretStore`,`ClusterSecretStore`...) tries to be deployed before than the CRDs needed to recognize them.

Reference: [https://external-secrets.io/v0.6.1/examples/gitops-using-fluxcd/](https://external-secrets.io/v0.6.1/examples/gitops-using-fluxcd/) 

 

## The solution

Let's see the conditions to start working on a solution:

- The External Secrets operator is deployed with Helm, and admits disabling the CRDs deployment
- The race condition only affects the deployment of `CustomResourceDefinition` and the CRs needed later
- CRDs can be deployed directly from the Git repository of the project using a Flux `Kustomization`
- Required CRs can be deployed using a Flux `Kustomization` too, allowing dependency between CRDs and CRs
- All previous manifests can be applied with a Kubernetes `kustomization`

## Prerequisites

- Kind
- AWS Creds
- Secret stored in AWS Secret Manager for testing
- SSH key and added to github

## 1- Repository Structure For Using with Flux

```yaml
.
├── clusters
│   └── my-cluster
│       ├── cluster-secrets.yaml
│       └── flux-system
│           ├── gotk-components.yaml
│           ├── gotk-sync.yaml
│           └── kustomization.yaml
├── cluster-secrets
│   └── cluster-secrets.yaml
└── secrets
    ├── aws-secret-store.yaml
    └── aws.yaml
```

## **Main components**

- ***cluster-secrets/cluster-secrets.yaml***

This file will contain the main configurations and requirements to install secret management operator and all its dependencies 

**Contents:**

1- External Secrets GitRepository & HelmRepository

We will getting them from `external-secrets` repository

```yaml
# GitRepository
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 10m
  ref:
    branch: main
  url: http://github.com/external-secrets/external-secrets
---
# HelmRepository
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 10m
  url: https://charts.external-secrets.io
---
```

2- External Secrets CRDs

We will getting them from `external-secrets` repository as well

```yaml
---
# external secrets crds
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: external-secrets-crds
  namespace: flux-system
spec:
  interval: 10m
  [path: ./deploy/crds](https://www.notion.so/Secrets-Management-f6add2cba4be4faa8bbad1276fb0455e)
  prune: true
  sourceRef:
    kind: GitRepository
    name: external-secrets
---
```

3- External Secrets HelmRelease

We will getting them from `external-secrets` repository as well and make sure `installCRDs`

is `false` to avoid the race condition

```yaml
---
# external secrets helm release
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  # Override Release name to avoid the pattern Namespace-Release
  # Ref: https://fluxcd.io/docs/components/helm/api/#helm.toolkit.fluxcd.io/v2beta1.HelmRelease
  releaseName: external-secrets
  targetNamespace: external-secrets
  interval: 10m
  chart:
    spec:
      chart: external-secrets
      sourceRef:
        kind: HelmRepository
        name: external-secrets
        namespace: flux-system
  values:
    installCRDs: false

  # Ref: https://fluxcd.io/docs/components/helm/api/#helm.toolkit.fluxcd.io/v2beta1.Install
  install:
    createNamespace: true
---
```

4- External Secrets Secrets (CRs) 

In this guide the secrets are in the same repository you can create as many CRs as you need, this is one secret for elaboration

```yaml
---
# external secrets secrets
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: external-secrets-secrets
  namespace: flux-system
spec:
  dependsOn:
    - name: external-secrets-crds
  interval: 10m
  # This is where the custom resources live (SecretStore, ExternalSecret)
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./secrets
  prune: true
  validation: client
```

- ***clusters/my-cluster/cluster-secrets***

This is the Kustomization file, the manifest of external secrets resources

**Contents:**

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: cluster-secrets
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ../cluster-secrets
  prune: true
  validation: client
```

- ***secrets/aws-secret-store.yaml***

This file has the configuration for aws-authentication using key and secret, or you can make it using service account

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: flux-system
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-north-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: awssm-secret
            key: access-key
          secretAccessKeySecretRef:
            name: awssm-secret
            key: secret-access-key
```

- ***secrets/aws.yaml***

This CR has describes what data should be fetched, how the data should be transformed and saved as a `Kind=Secret`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: new-secret
  namespace: flux-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: secret-to-be-created
    creationPolicy: Owner
  data:
  - secretKey: new-secret
    remoteRef:
      key: "<key>"
      property: "<value>"
```

## Deployment Steps

- Create kind cluster and namespace flux-system

```yaml
kind create cluster --name my-cluster
kubectl create ns flux-system
```

- Create secret for external-secrets operator for pulling from AWS secret manager

```

kubectl create secret generic awssm-secret --from-literal access-key=$AWS_ACCESS_KEY_ID --from-literal secret-access-key=$AWS_SECRET_ACCESS_KEY  -n flux-system
```

- Create secret for ssh-key

```yaml
kubectl create secret -n flux-system generic ssh-credentials --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts
```

- Bootstrap the cluster

```yaml
flux bootstrap github --owner=<github-owner> --repository=gitops --branch="<branch>" --path=clusters/my-cluster --personal
```

- Wait for the cluster to be loaded then `kubectl get pods -A` should be like the following

```yaml
NAMESPACE            NAME                                                READY   STATUS    RESTARTS   AGE
external-secrets     external-secrets-754db4f657-cl5ds                   1/1     Running   0          44m
external-secrets     external-secrets-cert-controller-59b6f5bffc-r5xrc   1/1     Running   0          44m
external-secrets     external-secrets-webhook-bb948577d-z2ld2            1/1     Running   0          44m
flux-system          helm-controller-56fc8dd99d-xz57z                    1/1     Running   0          44m
flux-system          kustomize-controller-bc455c688-gjwrt                1/1     Running   0          44m
flux-system          notification-controller-644f548fb6-kdvbr            1/1     Running   0          44m
flux-system          source-controller-7f66565fb8-6jcw2                  1/1     Running   0          44m
kube-system          coredns-6d4b75cb6d-6s6k8                            1/1     Running   0          44m
kube-system          coredns-6d4b75cb6d-zmx82                            1/1     Running   0          44m
kube-system          etcd-my-cluster-control-plane                       1/1     Running   0          45m
kube-system          kindnet-8q52l                                       1/1     Running   0          44m
kube-system          kube-apiserver-my-cluster-control-plane             1/1     Running   0          45m
kube-system          kube-controller-manager-my-cluster-control-plane    1/1     Running   0          45m
kube-system          kube-proxy-jth45                                    1/1     Running   0          44m
kube-system          kube-scheduler-my-cluster-control-plane             1/1     Running   0          45m
local-path-storage   local-path-provisioner-9cd9bd544-4ftdc              1/1     Running   0          44m
```

- Get the secrets you’ll find `secret-to-be-created` is available on the cluster

```yaml
NAMESPACE          NAME                                     TYPE                                   DATA   AGE
default            aws-sm-crs-secret                        addons.cluster.x-k8s.io/resource-set   1      45m
external-secrets   external-secrets-webhook                 Opaque                                 4      44m
flux-system        awssm-secret                             Opaque                                 2      45m
flux-system        flux-system                              Opaque                                 3      44m
flux-system        secret-to-be-created                     Opaque                                 1      38m
flux-system        sh.helm.release.v1.external-secrets.v1   helm.sh/release.v1                     1      44m
flux-system        ssh-credentials                          Opaque                                 3      45m
kube-system        bootstrap-token-abcdef                   bootstrap.kubernetes.io/token          6      45m
```

Repository Example [here](https://github.com/waleedhammam/gitops/tree/secrets)

## 2- Using with WGE

## Prerequisites

- WGE cluster. get one from [here](https://github.com/weaveworks/clusters-config/blob/main/docs/cluster.md#requesting-a-cluster)
- AWS Creds
- Secret stored in AWS Secret Manager for testing

## Deployment

- Create secret for external-secrets operator for pulling from AWS secret manager and ssh secret key as before

```bash
kubectl create secret generic awssm-secret --from-literal access-key=$AWS_ACCESS_KEY_ID --from-literal secret-access-key=$AWS_SECRET_ACCESS_KEY
kubectl create secret generic ssh-credentials --from-file=./identity --from-file=./identity.pub --from-file=./known_hosts
```

- Add the required files as structured before to the repository in management cluster, commit & push
- Secret Should appear after reconciliation

## Using with Leaf cluster

**Goal**: To bootstrap the leaf cluster with flux installed & secret to authenticate ESO

**Example**: [repo](https://github.com/waleedhammam/wge-dev/tree/main/clusters)

**Structure** 

```yaml
➜  wge-dev git:(main) tree
.
└── clusters
    ├── bases
    │   └── rbac
    │       └── wego-admin.yaml
    ├── external-secrets
    │   └── external-secrets.yaml
    ├── management
    │   ├── capi
    │   │   ├── bootstrap
    │   │   │   ├── aws-sm-creds.yaml  # to move the secret to leaf cluster
    │   │   │   ├── calico-crs-configmap.yaml
    │   │   │   ├── calico-crs.yaml
    │   │   │   └── capi-gitops-cluster-bootstrap-config.yaml
    │   │   ├── profiles
    │   │   │   └── profile-repo.yaml
    │   │   └── templates
    │   │       └── capd-template.yaml
    │   ├── external-secrets.yaml
    │   └── flux-system
    │       ├── gotk-components.yaml
    │       ├── gotk-sync.yaml
    │       └── kustomization.yaml
    └── secrets
        ├── management
        │   ├── aws-secret-store.yaml
        │   └── aws.yaml
        └── prod
```

**1- How to create the secret** 

- First when creating the management cluster we will need to create manually a secret for authenticating the SecretStore also we need to create`ClusterResourceSet` for the AWS secret to be able to bootstrap it to leaf cluster. This will be copied for bootstrap location as shown before.

```bash
# Create secret for external-secrets operator for pulling from AWS secret manager with access key & secret key and create ClusterResourceSet for deploying the secret to leaf clusters
kubectl create secret generic awssm-secret --from-literal access-key=$AWS_ACCESS_KEY_ID --from-literal secret-access-key=$AWS_SECRET_ACCESS_KEY  -n flux-system --dry-run=client -o yaml > aws-sm-crs-data.yaml
kubectl apply -f aws-sm-crs-data.yaml
kubectl create secret generic aws-sm-crs-secret --from-file=aws-sm-crs-data.yaml --type=addons.cluster.x-k8s.io/resource-set
rm aws-sm-crs-data.yaml
```

**2- Create `ClusterBootstrapConfig` to bootstrap the leaf cluster with flux installed and the secret mounted**

- In order to be able to use **`ClusterBootstrapConfig`** we need to set an env variable `EXP_CLUSTER_RESOURCE_SET` to be `true`
- Also to use the `ClusterBootstrapConfig` we need to set a label `weave.works/flux: "bootstrap"` to target the booting clusters with it

Reference: [https://docs.gitops.weave.works/docs/cluster-management/getting-started/#profiles-and-clusters](https://docs.gitops.weave.works/docs/cluster-management/getting-started/#profiles-and-clusters)

```yaml
apiVersion: capi.weave.works/v1alpha1
kind: ClusterBootstrapConfig
metadata:
  name: capi-gitops
  namespace: default
spec:
  clusterSelector:
    matchLabels:
      weave.works/flux: "bootstrap"
  jobTemplate:
    generateName: "run-gitops-{{ .ObjectMeta.Name }}"
    spec:
      containers:
        - image: ghcr.io/fluxcd/flux-cli:v0.32.0
          imagePullPolicy: Always
          name: flux-bootstrap
          resources: {}
          volumeMounts:
            - name: kubeconfig
              mountPath: "/etc/gitops"
              readOnly: true
          args:
            [
              "bootstrap",
              "github",
              "--kubeconfig=/etc/gitops/value",
              "--owner=waleedhammam",
              "--repository=wge-dev",
              "--path=./clusters/{{ .ObjectMeta.Namespace }}/{{ .ObjectMeta.Name }}",
            ]
          envFrom:
            - secretRef:
                name: my-pat
          env:
            - name: EXP_CLUSTER_RESOURCE_SET
              value: "true"
      restartPolicy: Never
      volumes:
        - name: kubeconfig
          secret:
            secretName: "{{ .ObjectMeta.Name }}-kubeconfig"
```

**3- The cluster template**

For the cluster template we will need to add 2 labels

i) `weave.works/flux: bootstrap` to match the booting clusters with the `**ClusterBootstrapConfig`** job

ii) `secretmanager: aws` to match the the booting clusters with the `ClusterResourceSet` for the AWS secret 

Example for the template

```yaml
apiVersion: capi.weave.works/v1alpha1
kind: CAPITemplate
metadata:
  name: cluster-template-development
  namespace: default
spec:
  description: This is the std. CAPD template
  params:
    - name: CLUSTER_NAME
      required: true
      description: This is used for the cluster naming.
    - name: NAMESPACE
      description: Namespace to create the cluster in
    - name: KUBERNETES_VERSION
      description: Kubernetes version to use for the cluster
      options: ["1.19.11", "1.21.1", "1.22.0", "1.23.3"]
    - name: CONTROL_PLANE_MACHINE_COUNT
      description: Number of control planes
      options: ["1", "2", "3"]
    - name: WORKER_MACHINE_COUNT
      description: Number of control planes
  resourcetemplates:
    - apiVersion: gitops.weave.works/v1alpha1
      kind: GitopsCluster
      metadata:
        name: "${CLUSTER_NAME}"
        namespace: "${NAMESPACE}"
        labels:
          weave.works/flux: bootstrap
          weave.works/apps: "capd"
        annotations:
          metadata.weave.works/dashboard.prometheus: https://prometheus.io/
      spec:
        capiClusterRef:
          name: "${CLUSTER_NAME}"
    - apiVersion: cluster.x-k8s.io/v1beta1
      kind: Cluster
      metadata:
        name: "${CLUSTER_NAME}"
        namespace: "${NAMESPACE}"
        labels:
          cni: calico
          secretmanager: aws
      spec:
        clusterNetwork:
          pods:
            cidrBlocks:
              - 192.168.0.0/16
          serviceDomain: cluster.local
          services:
            cidrBlocks:
              - 10.128.0.0/12
        controlPlaneRef:
          apiVersion: controlplane.cluster.x-k8s.io/v1beta1
          kind: KubeadmControlPlane
          name: "${CLUSTER_NAME}-control-plane"
          namespace: "${NAMESPACE}"
        infrastructureRef:
          apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
          kind: DockerCluster
          name: "${CLUSTER_NAME}"
          namespace: "${NAMESPACE}"
    - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
      kind: DockerCluster
      metadata:
        name: "${CLUSTER_NAME}"
        namespace: "${NAMESPACE}"
    - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
      kind: DockerMachineTemplate
      metadata:
        name: "${CLUSTER_NAME}-control-plane"
        namespace: "${NAMESPACE}"
      spec:
        template:
          spec:
            extraMounts:
              - containerPath: /var/run/docker.sock
                hostPath: /var/run/docker.sock
    - apiVersion: controlplane.cluster.x-k8s.io/v1beta1
      kind: KubeadmControlPlane
      metadata:
        name: "${CLUSTER_NAME}-control-plane"
        namespace: "${NAMESPACE}"
      spec:
        kubeadmConfigSpec:
          clusterConfiguration:
            apiServer:
              certSANs:
                - localhost
                - 127.0.0.1
                - 0.0.0.0
            controllerManager:
              extraArgs:
                enable-hostpath-provisioner: "true"
          initConfiguration:
            nodeRegistration:
              criSocket: /var/run/containerd/containerd.sock
              kubeletExtraArgs:
                cgroup-driver: cgroupfs
                eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
          joinConfiguration:
            nodeRegistration:
              criSocket: /var/run/containerd/containerd.sock
              kubeletExtraArgs:
                cgroup-driver: cgroupfs
                eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
        machineTemplate:
          infrastructureRef:
            apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
            kind: DockerMachineTemplate
            name: "${CLUSTER_NAME}-control-plane"
            namespace: "${NAMESPACE}"
        replicas: "${CONTROL_PLANE_MACHINE_COUNT}"
        version: "${KUBERNETES_VERSION}"
    - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
      kind: DockerMachineTemplate
      metadata:
        name: "${CLUSTER_NAME}-md-0"
        namespace: "${NAMESPACE}"
      spec:
        template:
          spec: {}
    - apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
      kind: KubeadmConfigTemplate
      metadata:
        name: "${CLUSTER_NAME}-md-0"
        namespace: "${NAMESPACE}"
      spec:
        template:
          spec:
            joinConfiguration:
              nodeRegistration:
                kubeletExtraArgs:
                  cgroup-driver: cgroupfs
                  eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
    - apiVersion: cluster.x-k8s.io/v1beta1
      kind: MachineDeployment
      metadata:
        name: "${CLUSTER_NAME}-md-0"
        namespace: "${NAMESPACE}"
      spec:
        clusterName: "${CLUSTER_NAME}"
        replicas: "${WORKER_MACHINE_COUNT}"
        selector:
          matchLabels: null
        template:
          spec:
            bootstrap:
              configRef:
                apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
                kind: KubeadmConfigTemplate
                name: "${CLUSTER_NAME}-md-0"
                namespace: "${NAMESPACE}"
            clusterName: "${CLUSTER_NAME}"
            infrastructureRef:
              apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
              kind: DockerMachineTemplate
              name: "${CLUSTER_NAME}-md-0"
              namespace: "${NAMESPACE}"
            version: "${KUBERNETES_VERSION}"
```

**3- Creating the leaf cluster will lead to bootstrap it with the secret ready to be used to authenticate the SecretStore**

```bash
➜  wge-dev git:(main) ✗ k get secret -A --kubeconfig dev.kubeconfig
NAMESPACE         NAME                                             TYPE                                  DATA   AGE
default           default-token-j98vw                              kubernetes.io/service-account-token   3      4m11s
flux-system       awssm-secret                                     Opaque                                2      104s
flux-system       default-token-tvhv4                              kubernetes.io/service-account-token   3      3m29s
flux-system       flux-system                                      Opaque                                3      3m25s
flux-system       helm-controller-token-wvzvp                      kubernetes.io/service-account-token   3      3m27s
flux-system       kustomize-controller-token-cktr2                 kubernetes.io/service-account-token   3      3m27s
flux-system       notification-controller-token-vbd84              kubernetes.io/service-account-token   3      3m27s
flux-system       source-controller-token-7fh62                    kubernetes.io/service-account-token   3      3m27s
.
.
.

```
