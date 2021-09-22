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
CATALOG_REPO_URL=https://github.com/weaveworks/profiles-catalog.git 
PR_BRANCH=""

if [ ! -n "$1"  ]; then
    echo "Please supply profile name"
    exit 10
fi

if [ ! -n "$GITHUB_TOKEN"  ]; then
    echo "GITHUB_TOKEN has not been configured"
    echo "Please add create a token https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token"
    exit 10
fi

PROFILE=$1
PROFILE_DIR="${PWD}/$PROFILE"
HASH="$(openssl rand -base64 12)"
PR_BRANCH="add-$PR_BRANCH-$HASH"

if [ ! -d $PROFILE_DIR ]; then 
    echo "Profile does not exist in current repo"
    exit 10
fi
echo "Installing testing cluster"
#bash $BINDIR/kind.sh

echo "Check if repo folder exists ..."
if [ ! -d $PROFILE_DIR ]; then 
    mkdir ${REPODIR}
else
    rm -rf ${REPODIR}
    mkdir ${REPODIR}
fi
echo "Clone test repo"
git clone https://github.com/$TEST_REPO_USER/$TEST_REPO $REPODIR

cd $REPODIR

echo "Creating cluster folder"
mkdir -p clusters/my-cluster

echo "Creating Kustomization"
flux create kustomization $PROFILE --export \
    --path ./$PROFILE \
    --interval=1m \
    --source=GitRepository/flux-system \
    --prune=true > clusters/my-cluster/$PROFILE.yaml

echo "Boostrapping flux"
flux bootstrap github \
    --owner=$TEST_REPO_USER \
    --repository=$TEST_REPO \
    --branch=main \
    --path=clusters/my-cluster

echo "Adding Profile to repo"
pctl add --name $PROFILE \
--profile-repo-url $CATALOG_REPO_URL \
--git-repository flux-system/flux-system \
--profile-path ./$PROFILE 

echo "Commiting profile to repo"
git add . && git commit -m "adding profile" && git push

echo "Reconciling Repos"
flux reconcile kustomization flux-system
flux reconcile kustomization $PROFILE 
