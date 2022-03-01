output "dhcp_ip" {
  value = metal_device.dhcp_nat.network.0.address
}
output "host_ips" {
  value = metal_device.host.*.network.0.address
}

output "terraform_state_location" {
  value = <<EOV
${path.cwd}/terraform.tfstate.d/${terraform.workspace}/terraform.tfstate
EOV
}
