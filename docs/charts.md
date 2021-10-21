## Charts


### Install using 
```

helm repo add ttps://stunning-bassoon-592abc80.pages.github.io/

helm repo add --force-update profiles-catalog 'https://@raw.githubusercontent.com/weaveworks/profiles-catalog/observability-v2/charts/'

helm install observability profiles-catalog/observability

```