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

variable "private_key_path" {
  description = "the path to the private key to use for SSH"
  type        = string
}

variable "vsphere_user" {
  description = "vsphere user"
  type        = string
}

variable "vsphere_password" {
  description = "vsphere password"
  type        = string
}


module "hosts" {
  source = "./modules/equinix"
  org_id= var.org_id
  private_key_path=var.private_key_path
  metal_auth_token=var.metal_auth_token
}

module "vsa_config" {
  source = "./modules/vcsa"
  vsphere_user = var.vsphere_user
  vsphere_password = var.vsphere_password
  metal_auth_token = var.metal_auth_token
  project_id = var.project_id
  ipAddr = module.hosts.access_public_ipv4
  depends_on=[
    module.hosts]
}

