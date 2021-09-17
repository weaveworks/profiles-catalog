# Contour Profile
An example [profile](https://github.com/weaveworks/profiles). Contains the profile `contour`.


[Please review the documentation for the upsteam helm chart](https://github.com/bitnami/charts/tree/master/bitnami/contour/)


https://github.com/bitnami/charts/tree/master/bitnami/contour/

Parmaters still under review
envoy.replicaCount = 2

https://projectcontour.io/guides/resource-limits/
contour.resources.requests
envoy.resources.requests

contour.podAntiAffinityPreset = soft (currently)
envoy.podAffinityPreset not set
envoy.podAntiAffinityPreset not set
envoy.nodeAffinityPreset.type not 

prometheus.serviceMonitor.namespace
prometheus.serviceMonitor.enabled
prometheus.serviceMonitor.jobLabel
prometheus.serviceMonitor.interval

