variable "vsphere_user" {
  description = "vsphere user"
  type        = string
}

variable "vsphere_server" {
  description = "vsphere password"
  type        = string
}


variable "vsphere_password" {
  description = "vsphere password"
  type        = string
}

variable "esxi_ip_private" {
  description = "ESXI IP private"
  type        = string
}
variable "esxi_ip_public" {
  description = "ESXI IP public"
  type        = string
}

#VSPHERE
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

resource "vsphere_datacenter" "dc1" {
  name = "dc1"
  tags              = []
  custom_attributes = {}
}

data "vsphere_host_thumbprint" "thumbprint" {
  address = var.esxi_ip_public
  insecure = true
}

resource "vsphere_host" "esxi1" {
  hostname = var.esxi_ip_public
  username   = "root"
  password   = var.vsphere_password
  datacenter = vsphere_datacenter.dc1.moid
  thumbprint = data.vsphere_host_thumbprint.thumbprint.id
}