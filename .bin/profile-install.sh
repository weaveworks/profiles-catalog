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

if [ ! -d $PROFILE_DIR ]; then 
    echo "Profile does not exist in current repo"
    exit 10
fi
echo "Installing testing cluster"
bash $BINDIR/kind.sh


echo "Boostrapping flux"
wego flux bootstrap github \
    --owner=$TEST_REPO_USER \
    --repository=$TEST_REPO \
    --branch=main \
    --namespace wego-system \
    --path=clusters/my-cluster \
    --personal \
    --read-write-key

echo "Clone test repo"
git clone https://github.com/$TEST_REPO_USER/$TEST_REPO $REPODIR

cd $REPODIR

echo "Creating Kustomization"
wego flux create kustomization $PROFILE --export \
    --path ./$PROFILE \
    --interval=1m \
    --source=GitRepository/wego-system \
    -n wego-system \
    --prune=true > clusters/my-cluster/$PROFILE.yaml

echo "Adding Profile to repo"
pctl add --name $PROFILE \
--profile-repo-url $CATALOG_REPO_URL \
--git-repository wego-system/wego-system \
--profile-path ./$PROFILE 

echo "Commiting profile to repo"
git add . && git commit -m "adding profile" && git push

echo "Reconciling Repos"
echo "Reconciling wego-system"
wego flux reconcile kustomization --namespace wego-system wego-system

echo "sleeping (TODO:FIX (Hack) Fux/wego does NOT create the kustomization right away)"
sleep 60

echo "Reconciling $PROFILE"
wego flux reconcile kustomization --namespace wego-system $PROFILE 

echo "sleeping (TODO:FIX (Hack) Fux/wego does NOT create the kustomization right away)"
sleep 60

echo "TODO:Checking if profile has been installed sucesfully"
kubectl wait --for=condition=ready --timeout=2m pod -l app.kubernetes.io/name=$PROFILE 

echo "TODO:Remove $PROFILE from repo"