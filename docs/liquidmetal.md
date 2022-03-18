# Liquid Metal Environment Provision


### Step 1: Create Hosts in Equinix 
```
cd terraform/liquidmetal && terraform plan

terraform apply
```
## Step 2: Update mvm host ip in makefiles/mvm/Makefile
"HOST_ENDPOINT=<update_ip>:9090"


### Step 2: Create Local KIND Bootstrap Cluster
```
cd ../../makefiles/mvm/ && make create-mvm-mgmt-cluster
```

### Step 3: Add kubeconfig to weaveworks/profiles-catalog
```
make get-mvm-mgmt-config
export KUBECONFIG=/tmp/config.yaml
```

### Step 4: Install Calico

cd ../capi && make install-calico


### Step 5: Install mvm provider
```
cd ../mvm && make configure-and-install-mvm-provider
```

### Step 6: Install runner
```
make install-github-runner
```

### Output

1. DHCP/NAT Host
2. Host-0
    1. Containerd
    2. Flintlock
    3. Firecracker
    4. MVM Management Cluster
        1. CAPI with Microvm Provisioner
        2. Github Runner

