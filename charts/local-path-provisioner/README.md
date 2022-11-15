# Local path provisioner profile for weave gitops

This profile is based on the local-path-provisioner from Rancher.
The Rancher Helm chart is used as a subchart.

This profile will set the local-path-provisioner as the default storage class.

## Uupgrading the Rancher chart

As the Rancher chart is not published in a Helm repository,
to update the version you will have to download the chart from:
https://github.com/rancher/local-path-provisioner/tree/master/deploy/chart/local-path-provisioner
And copy that into the /charts folder.

Also remember to update the version in the profile's Chart.yaml to refer to the Rancher chart version.
