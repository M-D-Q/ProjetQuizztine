resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  count = length(var.vm_names)
  name = "${var.vm_names[count.index]}-PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowFlaskApp"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowPrometheus"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGrafana"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowNagios"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5666" # Nagios NRPE port
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Create 4 network interfaces
resource "azurerm_network_interface" "my_terraform_nic" {
  count = length(var.vm_names)
  name = "${var.vm_names[count.index]}-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration_${count.index}"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip[count.index].id
  }
}


resource "azurerm_network_interface_security_group_association" "example" {
  count = length(var.vm_names)
  network_interface_id    = azurerm_network_interface.my_terraform_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}


# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create 4 virtual machines
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  count = length(var.vm_names)
  name = "${var.vm_names[count.index]}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic[count.index].id]
  size                  = "Standard_B1ms"

  os_disk {
    name                 = "myOsDisk-${count.index}"
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "${var.vm_names[count.index]}"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

  #copy ssh key
resource "null_resource" "private_key_file" {
  provisioner "local-exec" {
   command = "echo '${tls_private_key.example_ssh.private_key_pem}' > ./ansible_directory/id_rsa"
}
}


  #render inventory file & vars file from template, and overwrite the old ones in the ansible directory
resource "null_resource" "rendered_ansible_inventory" {
  provisioner "local-exec" {
    command = "echo '${local.inventory_yaml}' > ansible_directory/inventory/inventory.yml"
  }
}
resource "null_resource" "rendered_ansible_inventory" {
  provisioner "local-exec" {
    command = "echo '${local.all_vars_yaml}' > ansible_directory/group_vars/all.yml"
  }
}

  #copy ansible dir into ansible vm (thats the last vm to be created)

resource "null_resource" "copy_ansible_directory" {
  provisioner "dir" {
    source      = "./ansible_directory"
    destination = "/tmp"
  }

  connection {
    type        = "ssh"
    user        = "azureuser"
    private_key = file("path/to/private/key")
    host        = azurerm_linux_virtual_machine.my_terraform_vm[-1].private_ip_address
  }
}

  #remote exec playbook.yml in VM

provisioner "remote-exec" {
  inline = [
    "ansible-playbook /tmp/ansible_directory/playbook.yml"
  ]

  connection {
    type        = "ssh"
    user        = "azureuser"
    private_key = file("${path.module}/id_rsa")
    host        = self.private_ip_address
  }
}

  #enjoy

  
}
