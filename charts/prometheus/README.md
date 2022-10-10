# Prometheus WGE Profile

This profile includes:

- flux podmonitor
- flux dashboards

## Adding or changing JSON dashboards

The file templates/dashboards.yaml contains the JSON dashboard spec.
The grafana dashboards include variables to be replaced in Grafana such as:
```
{{kind}}
```

Helm template engine will attempt to interpret these as Helm variables, but we want them passed through without Helm interpreting them.
You can get round this by quoting the variable inside backticks and double curly braces like this:
```
{{`{{`}}kind{{`}}`}}
```

This can be seen used in the upstream kube-prometheus-stack chart here:
- https://github.com/prometheus-community/helm-charts/blob/92a69db2825845e3032a6834dec21e9ec6a5f557/charts/kube-prometheus-stack/templates/grafana/dashboards-1.14/pod-total.yaml#L404

## Source Dashboards

The source of the dashboards, for flux these are located here:
- https://github.com/fluxcd/flux2/tree/main/manifests/monitoring/monitoring-config/dashboards
- https://github.com/steveww/pypodinfo/tree/main/kustomize/monitoring/dashboards
