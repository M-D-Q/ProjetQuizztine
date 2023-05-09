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

output "internal_ip_addresses" {
  value = [
    for index in range(length(azurerm_network_interface.my_terraform_nic)) : {
      vm_name = azurerm_linux_virtual_machine.my_terraform_vm[index].name
      internal_ip = azurerm_network_interface.my_terraform_nic[index].ip_configuration[0].private_ip_address
    }
  ]
  description = "List of internal IP addresses for the virtual machines"
}
output "custom_data_debug" {
  value = {
    for index, vm_name in var.vm_names : vm_name => base64encode("${file(local.startup_scripts[var.vm_names[index]])} ${local.vm_ips["Postgresql1"]} ${local.vm_ips["Monitoring"]} ${local.vm_ips["LB-database"]} ${local.vm_ips["Postgresql2"]}")
  }
}
