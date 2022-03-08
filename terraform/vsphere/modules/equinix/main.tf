terraform {
  required_providers {
    metal = {
      source = "equinix/metal"
    }
  }
}

# ## VARIABLES

variable "project_id" {
  description = "Project id"
  type        = string
  default     = "a5ffac5d-c1d3-4d71-bfdf-9158faf9f75c"
}

variable "org_id" {
  description = "Org id"
  type        = string
}


variable "metro" {
  description = "Metro to create resources in"
  type        = string
  default     = "am"
}

variable "server_type" {
  description = "The type/plan to use for devices"
  type        = string
  default     = "c3.small.x86"
}

variable "host_device_count" {
  description = "number of flintlock hosts to create"
  type        = number
  default     = 2
}

variable "metal_auth_token" {
  description = "Auth token"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "the path to the private key to use for SSH"
  type        = string
}

# ## VSPHERE VARS



# ## THE JUICE
 
provider "metal" {
  auth_token = var.metal_auth_token
}


# Create VLAN in project
resource "metal_vlan" "vlan" {
  description = "VLAN for liquid-metal-demo"
  metro       = var.metro
  project_id  = var.project_id
}


# Create N devices to act as flintlock hosts
resource "metal_device" "host" {
  count               = var.host_device_count
  hostname            = "host-esxi-${count.index}"
  plan                = var.server_type
  metro               = var.metro
  operating_system    = "vmware_esxi_7_0"
  billing_cycle       = "hourly"
#   user_data           = "#!/bin/bash\ncurl -s https://raw.githubusercontent.com/masters-of-cats/a-new-hope/main/install.sh | bash -s"
  project_id          = var.project_id
}

# Update the host devices' networking to be Hybrid-Bonded with VLAN attached
resource "metal_port" "bond0_host" {
  count    = var.host_device_count
  port_id  = [for p in metal_device.host[count.index].ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = ["7f43dac6-2900-4adf-810e-919e8f466f52"]
}

output "access_public_ipv4" {
  value = metal_device.host[0].access_public_ipv4
    depends_on = [  
      metal_device.host[0]
    ]
}

#https://storage.googleapis.com/capv-images/release/v1.17.3/ubuntu-1804-kube-v1.17.3.ova