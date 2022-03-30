terraform {
  required_providers {
    metal = {
      source = "equinix/metal"
    }
  }
}
variable "project_id" {
  description = "Project id"
  type        = string
  default     = "a5ffac5d-c1d3-4d71-bfdf-9158faf9f75c"
}

variable "org_id" {
  description = "Org id"
  type        = string
}

variable "metal_auth_token" {
  description = "Auth token"
  type        = string
  sensitive   = true
}
variable "metro" {
  description = "Metro to create resources in"
  type        = string
  default     = "dc"
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


variable "private_key_path" {
  description = "the path to the private key to use for SSH"
  type        = string
}

variable "template_file_path" {
  description = "JSON template file path"
  type = string
  default = "templates/vcsa70_embedded_vCSA_on_VC.json"
}

variable "config_file_path" {
  description = "vcsa configuration JSON file path"
  type = string
  default = "/tmp/vcsa01_embedded_vCSA_on_VC.json"
}
variable "installcmd_file_path" {
  description = "command line file path"
  type = string
  default = "/Users/steve/Documents/vcsa/vcsa-cli-installer/mac/"
}


provider "metal" {
  auth_token = var.metal_auth_token
}

# Create N devices to act as flintlock hosts
resource "metal_device" "host" {
  hostname            = "host-esxi-0"
  plan                = var.server_type
  metro               = var.metro
  operating_system    = "vmware_esxi_7_0"
  billing_cycle       = "hourly"
#   user_data           = "#!/bin/bash\ncurl -s https://raw.githubusercontent.com/masters-of-cats/a-new-hope/main/install.sh | bash -s"
  project_id          = var.project_id
}

# Update the dhcp device networking to be Hybrid-Bonded with VLAN attached
resource "metal_port" "bond0_host" {
  port_id  = [for p in metal_device.host.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = ["7f43dac6-2900-4adf-810e-919e8f466f52"]
}

resource "local_file" "vcsa_json" {
    content = templatefile (
            var.template_file_path, 
            { 
              vc_fqdn =  metal_device.host.network.0.address,
              vc_user = "root",
              vc_user_pass = metal_device.host.root_password,
              vm_network = "VM Network",
              vdc = "dc0",
              datastore = "datastore1",
              host =  metal_device.host.network.0.address,
              cluster = "cluster0",
              vcsa_name = element(split(".", metal_device.host.network.0.address),0),
              vcsa_root_pass = metal_device.host.root_password,
              ntp_servers = "time.nist.gov",
              sso_password = metal_device.host.root_password
            }
            )
    filename = var.config_file_path
}
resource "null_resource" "setup_esxi_network" {
  connection {
    type        = "ssh"
    host        = metal_device.host.network.0.address
    user        = "root"
    port        = 22
    private_key = file(var.private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      "esxcli network vswitch standard portgroup set -p 'VM Network' --vlan-id 1000"
    ]
  }
}

resource "null_resource" "setup_vcsa" {
  provisioner "local-exec" {
    command = "${var.installcmd_file_path}/vcsa-deploy install --accept-eula --no-esx-ssl-verify ${var.config_file_path}"
  }
  depends_on = [
    local_file.vcsa_json
  ]
}
