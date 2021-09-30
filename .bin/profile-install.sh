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
TEST_REPO_USER=weaveworks
TEST_REPO=profiles-catalog-test
CATALOG_REPO_URL=git@github.com:weaveworks/profiles-catalog.git

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
bash $BINDIR/kind-slim.sh

echo "Check if repo folder exists ..."
if [ -d $REPODIR ]; then 
    rm -rf ${REPODIR}
fi

echo "Boostrapping flux"
gitops flux bootstrap github \
    --owner=$TEST_REPO_USER \
    --repository=$TEST_REPO \
    --branch=main \
    --namespace wego-system \
    --path=clusters/my-cluster \
    --personal \
    --read-write-key

echo "Clone test repo"
git clone git@github.com:$TEST_REPO_USER/$TEST_REPO.git $REPODIR


cd $REPODIR

echo "Check if config folder exists ..."
[[ -d ${REPODIR}/clusters/my-cluster ]] || mkdir -p ${REPODIR}/clusters/my-cluster

echo "Creating Kustomization"
gitops flux create kustomization $PROFILE --export \
    --path ./$PROFILE \
    --interval=1m \
    --source=GitRepository/wego-system \
    -n wego-system \
    --prune=true > clusters/my-cluster/$PROFILE.yaml

echo "Removing profile is it already exists"
echo "**Currently ptcl does not delete files to align profiles**"
echo "Check if profile folder exists ..."
if [ -d $PROFILE ]; then 
    rm -rf ${PROFILE}
fi

echo "Adding Profile to repo"
pctl add --name $PROFILE \
--profile-repo-url $CATALOG_REPO_URL \
--git-repository wego-system/wego-system \
--profile-path ./$PROFILE \
--profile-branch demo-profile

echo "Commiting profile to repo"
git add . && git commit -m "adding profile" && git push

echo "Reconciling Repos"
echo "Reconciling wego-system"
gitops flux reconcile kustomization --namespace wego-system wego-system

echo "sleeping (TODO:FIX (Hack) Fux/gitops does NOT create the kustomization right away)"
sleep 60

echo "Reconciling $PROFILE"
gitops flux reconcile kustomization --namespace wego-system $PROFILE 

echo "sleeping (TODO:FIX (Hack) Fux/gitops does NOT create the kustomization right away)"
sleep 60

echo "TODO:Checking if profile has been installed sucesfully"

echo "TODO:Remove $PROFILE from repo"