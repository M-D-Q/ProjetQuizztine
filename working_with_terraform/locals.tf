locals {
  startup_scripts = {
    "AnsibleVM"       = "14-04/ansiblevm.sh"
    "Postgresql1"     = "14-04/master_psql.sh"
    "Postgresql2"     = "14-04/slave_psql.sh"
    "Flask"           = "14-04/flask_server.sh"
    "LB-database"     = "14-04/database_lb.sh"
    "Monitoring"      = "14-04/server_monitoring.sh"
    # Add more mappings as needed
  }

  static_internal_ips = {
    "AnsibleVM"   = "10.0.1.9"
    "Postgresql1" = "10.0.1.10"
    "Postgresql2" = "10.0.1.11"
    "Flask"       = "10.0.1.12"
    "LB-database" = "10.0.1.13"
    "Monitoring"  = "10.0.1.14"
    # Add more mappings as needed
  }

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
}

