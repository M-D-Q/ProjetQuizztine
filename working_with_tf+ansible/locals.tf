locals {

  vm_name_to_index = {
    for index, vm_name in var.vm_names : vm_name => index
  }

  vm_ips = {
    for index, vm_name in var.vm_names : vm_name => azurerm_network_interface.my_terraform_nic[index].private_ip_address
  }

  vm_name_to_ip = {
    for item in [
      for index in range(length(azurerm_network_interface.my_terraform_nic)) : {
        vm_name = var.vm_names[index]
        internal_ip = azurerm_network_interface.my_terraform_nic[index].ip_configuration[0].private_ip_address
      }
    ] : item.vm_name => item.internal_ip
  }

  inventory_yaml = templatefile("${path.module}/inventory.tpl", {
    master_ip      = azurerm_linux_virtual_machine.my_terraform_vm[0].private_ip_address
    slave_ip       = azurerm_linux_virtual_machine.my_terraform_vm[1].private_ip_address
    lb_ip          = azurerm_linux_virtual_machine.my_terraform_vm[2].private_ip_address
    flask_ip       = azurerm_linux_virtual_machine.my_terraform_vm[3].private_ip_address
    monitoring_ip  = azurerm_linux_virtual_machine.my_terraform_vm[4].private_ip_address
  })

  all_vars_yaml = templatefile("${path.module}/all.tpl", {
    master_ip      = azurerm_linux_virtual_machine.my_terraform_vm[0].private_ip_address
    slave_ip       = azurerm_linux_virtual_machine.my_terraform_vm[1].private_ip_address
    lb_ip          = azurerm_linux_virtual_machine.my_terraform_vm[2].private_ip_address
    monitoring_ip  = azurerm_linux_virtual_machine.my_terraform_vm[4].private_ip_address
  })
}

