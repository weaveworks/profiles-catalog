terraform {
  required_providers {
    metal = {
      source = "equinix/metal"
    }
  }
}

## VARIABLES

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

variable "ts_auth_key" {
  description = "Auth key for tailscale vpn"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "the path to the private key to use for SSH"
  type        = string
}

variable "flintlock_version" {
  description = "the version of flintlock to provision hosts with (default: latest)"
  type        = string
}

variable "firecracker_version" {
  description = "the version of firecracker to provision hosts with (default: latest)"
  type        = string
}

## THE JUICE

provider "metal" {
  auth_token = var.metal_auth_token
}



# Create device for dhcp, nat routing, vpn etc
resource "metal_device" "dhcp_nat" {
  hostname            = "dhcp-nat"
  plan                = var.server_type
  metro               = var.metro
  operating_system    = "ubuntu_20_04"
  billing_cycle       = "hourly"
  user_data           = "#!/bin/bash\ncurl -s https://raw.githubusercontent.com/masters-of-cats/a-new-hope/main/install.sh | bash -s"
  project_id          = var.project_id
}

# Update the dhcp device networking to be Hybrid-Bonded with VLAN attached
resource "metal_port" "bond0_dhcp" {
  port_id  = [for p in metal_device.dhcp_nat.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [1000]
}

# Create N devices to act as flintlock hosts
resource "metal_device" "host" {
  count               = var.host_device_count
  hostname            = "host-${count.index}"
  plan                = var.server_type
  metro               = var.metro
  operating_system    = "ubuntu_20_04"
  billing_cycle       = "hourly"
  user_data           = "#!/bin/bash\ncurl -s https://raw.githubusercontent.com/masters-of-cats/a-new-hope/main/install.sh | bash -s"
  project_id          = var.project_id
}

# Update the host devices' networking to be Hybrid-Bonded with VLAN attached
resource "metal_port" "bond0_host" {
  count    = var.host_device_count
  port_id  = [for p in metal_device.host[count.index].ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [1000]
}

# Set up the vlan, dhcp server, nat routing and the vpn on the dhcp_nat device
resource "null_resource" "setup_dhcp_nat" {
  connection {
    type        = "ssh"
    host        = metal_device.dhcp_nat.network.0.address
    user        = "root"
    port        = 22
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = "files/vlan.sh"
    destination = "/root/vlan.sh"
  }

  provisioner "file" {
    source      = "files/dhcp.sh"
    destination = "/root/dhcp.sh"
  }

  provisioner "file" {
    source      = "files/nat.sh"
    destination = "/root/nat.sh"
  }

  provisioner "file" {
    source      = "files/tailscale.sh"
    destination = "/root/tailscale.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/vlan.sh",
      "chmod +x /root/dhcp.sh",
      "chmod +x /root/nat.sh",
      "chmod +x /root/tailscale.sh",
      "VLAN_ID=1000 ADDR=2 /root/vlan.sh",
      "VLAN_ID=1000 /root/dhcp.sh",
      "VLAN_ID=1000 /root/nat.sh",
      "AUTH_KEY=${var.ts_auth_key} /root/tailscale.sh",
    ]
  }
}

# Set up the vlan and configure flintlock on the hosts
resource "null_resource" "setup_hosts" {
  count = var.host_device_count
  connection {
    type        = "ssh"
    host        = metal_device.host[count.index].network.0.address
    user        = "root"
    port        = 22
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = "files/vlan.sh"
    destination = "/root/vlan.sh"
  }

  provisioner "file" {
    source      = "files/flintlock.sh"
    destination = "/root/flintlock.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/vlan.sh",
      "chmod +x /root/flintlock.sh",
      "VLAN_ID=1000 ADDR=${count.index + 3} /root/vlan.sh",
      "VLAN_ID=1000 FLINTLOCK=${var.flintlock_version} FIRECRACKER=${var.firecracker_version} /root/flintlock.sh",
    ]
  }
}
