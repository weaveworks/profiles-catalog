#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -e
set -o pipefail

export PATH=$PATH

BINDIR="${PWD}/.bin"
REPODIR="${PWD}/.repo"
PROFILE=""
PROFILE_DIR=""
TEST_REPO_USER=ww-customer-test
TEST_REPO=profile-test-repo 
CATALOG_REPO_URL=ssh://git@github.com/weaveworks/profiles-catalog.git 

if [ ! -n "$1"  ]; then
    echo "Please supply profile name"
    exit 10
fi

if [ ! -n "$GITHUB_TOKEN"  ]; then
    echo "GITHUB_TOKEN has not been configured"
    echo "Please add create a token https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token"
    exit 10
fi

echo "Install secret to use with catalog repo"
flux create secret git catalog-secret --url ${CATALOG_REPO_URL}  


echo "Install catalog to cluster"
cat <<EOF | kubectl apply -f -
apiVersion: weave.works/v1alpha1
kind: ProfileCatalogSource
metadata:
  name: enterprise-profiles
spec:
  repositories:
  - url: ${CATALOG_REPO_URL}
    secretRef:
      name: catalog-secret
EOF
