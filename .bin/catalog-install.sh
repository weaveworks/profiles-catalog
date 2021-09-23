#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -e
set -o pipefail

export PATH=$PATH
FLUX_NAMESPACE=wego-system
CATALOG_REPO_URL=ssh://git@github.com/weaveworks/profiles-catalog.git 

if ! kubectl get secret flux-system -n ${FLUX_NAMESPACE} 2>&1 >/dev/null; then
    echo "Cluster not bootraped"
    exit 1
fi

echo "Install catalog to cluster"
cat <<EOF | kubectl apply -f -
apiVersion: weave.works/v1alpha1
kind: ProfileCatalogSource
metadata:
  name: enterprise-profiles
  namespace: ${FLUX_NAMESPACE}
spec:
  repositories:
  - url: ${CATALOG_REPO_URL}
    secretRef:
      name: flux-system
EOF
