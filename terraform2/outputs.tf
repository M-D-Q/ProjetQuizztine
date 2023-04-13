output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_addresses" {
  value = [for i in azurerm_linux_virtual_machine.my_terraform_vm : i.public_ip_address]
}


output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}

