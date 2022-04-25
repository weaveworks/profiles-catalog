# Weave Gitops Profiles Catalog Repository

This repository is an example of how to buid Weave Gitops Profiles for a kubernetes cluster to be consumed by the Weave Gitops Profile controller.

[Weave Gitops Project on Github](https://github.com/weaveworks/weave-gitops)

# Usage

This repository is provided as an example of a collection of profiles for an organization that would like to build kubernetes clusters with platform components to build a PaaS like experience for developers.

This repository should not be used for production deployments as it requires further customisation for real world use.
In addition the default deployment values may not be properly secured.

The purpose of publishing this repository is to provide an example of Weave Gitops Profiles to be used in demos and as a base for further customisation.

Please read the documentation for how to set up a profiles-catalog repo of your own and how to consume it from Weave Gitops.

[Profiles Documentation](https://docs.gitops.weave.works/docs/cluster-management/profiles)

# Disclaimer

This repository is not guaranteed to be up to date and should not be considered the canonical source of the upstream Helm charts being used here.
Please use the upstream repositories for the canonical version and any release notes that effect security.

# Contents

The charts directory contains the list of profiles that become available once you have configured this repository as a Helm repo source for the profile controller.

These can be selected by the Weave Gitops cluster deployment UI and thus can be used to build a kubernetes platform with built in components preconfigured for your organization.

Copyright Weaveworks 2022
