# Liquid Metal Environment Provision


### Step 1: Create Hosts in Equinix 
```
cd terraform/liquidmetal && terraform plan

terraform apply
```


### Step 2: Create Local KIND Bootstrap Cluster
```
cd ../../makefiles/mvm/ && make create-mvm-bootstrap-cluster
```

### Step 3: Add kubeconfig to weaveworks/profiles-catalog secrets base64 encoded
```
make get-mvm-mgmt-config
cat config.yaml | base64
```

### Step 4: Update tailscale auth key in  weaveworks/profiles-catalog
https://tailscale.com/kb/1085/auth-keys/