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

variable "metal_auth_token" {
  description = "Auth token"
  type        = string
  sensitive   = true
}

# ## VSPHERE VARS

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

variable "ntp_servers" {
  description = "ntp servers"
  type = string
  default = "time.nist.gov"
}
variable "vcsa_fqdn" {
  description = "ntp servers"
  type = string
  default = "host0"
}


variable "installcmd_file_path" {
  description = "command line file path"
  type = string
  default = "/Users/steve/Documents/vcsa/vcsa-cli-installer/mac/"
}

variable "vsphere_user" {
  description = "vsphere user"
  type        = string
}

variable "vsphere_password" {
  description = "vsphere password"
  type        = string
}
variable "ipAddr" {
  description = "IP"
  type        = string
}
# variable "vsphere_server" {
#   description = "vsphere server"
#   type        = string
# }

# ## THE JUICE
provider "metal" {
  auth_token = var.metal_auth_token
}


resource "local_file" "vcsa_json" {
    content = templatefile (
            var.template_file_path, 
            { 
              vc_fqdn =  var.ipAddr,
              vc_user = var.vsphere_user
              vc_user_pass = var.vsphere_password,
              vm_network = "VM Network",
              vdc = "dc0",
              datastore = "datastore1",
              host =  var.ipAddr,
              cluster = "cluster0",
              vcsa_name = element(split(".", var.ipAddr),0),
              vcsa_root_pass = var.vsphere_password,
              ntp_servers = "time.nist.gov",
              sso_password = var.vsphere_password
            }
            )
    filename = var.config_file_path
}

resource "null_resource" "vcsa_install" {
  provisioner "local-exec" {
    command = "${var.installcmd_file_path}/vcsa-deploy install --accept-eula --no-esx-ssl-verify ${var.config_file_path}"
  }
}








#https://storage.googleapis.com/capv-images/release/v1.17.3/ubuntu-1804-kube-v1.17.3.ova