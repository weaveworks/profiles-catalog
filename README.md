# profiles-examples
This an example profile repository. It contains two profiles, `weaveworks-nginx` and `bitnami-nginx`

## Bitnami nginx

The `bitnami-nginx` profile is a profile consisting of a local chart, this local chart is a copy of the
[bitnami/nginx helm chart](https://github.com/bitnami/charts/tree/master/bitnami/nginx). When you deploy
this profile, it deploys the helm chart

Tag `bitnami-nginx/v0.0.1` exists and can be used to consume `v0.0.1` of the `bitnami-nginx` profile.

## Weaveworks nginx
The `weaveworks-nginx` profile is a profile consisting of 3 artifacts:

- A helm chart pointing to `bitnami/dokuwiki`
- A local `deloyment.yaml`
- The `bitnami-nginx` profile.

This profile demonstrates the 3 different types of artifacts you can write in a profile, and how the layout works. The
profile itself doesn't deploy anything meaningful, it just exists to demonstrate.

Tag `weaveworks-nginx/v0.1.0` exists and can be used to consume `v0.1.0` of the `weaveworks-nginx` profile.
