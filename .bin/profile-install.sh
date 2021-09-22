#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -e
set -o pipefail

export PATH=$PATH

BINDIR="${PWD}/.bin"
PROFILE=""
PROFILE_DIR=""
TEST_REPO=weaveworks/pctl-test-repo 
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
bash $BINDIR/kind.sh

echo "Adding Profile to repo"
pctl add --name $PROFILE \
--profile-repo-url $CATALOG_REPO_URL \
--pr-repo  $TEST_REPO \
--pr-branch $PR_BRANCH \
--create-pr \
--git-repository flux-system/flux-system \
--profile-path ./$PROFILE 