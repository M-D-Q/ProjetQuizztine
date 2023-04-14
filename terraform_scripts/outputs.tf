output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_addresses" {
  value = [for i in azurerm_linux_virtual_machine.my_terraform_vm : i.public_ip_address]
}
output "vm-names" {
  value = [for i in azurerm_linux_virtual_machine.my_terraform_vm : i.name]
}
output "vm-name_vm-ip" {
  value = [for i in azurerm_linux_virtual_machine.my_terraform_vm : format("%s - %s", i.name, i.public_ip_address)]
}

output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}

