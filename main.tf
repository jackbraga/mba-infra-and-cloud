terraform {
  required_version = " >= 0.13"

  required_providers {
    azurerm = {    
        source = "hashicorp/azurerm"
        version =">=2.26"
    }
  }
}

provider "azurerm" {
  features {
    
  }
}

resource "azurerm_resource_group" "rg-atividade_terraform" {
  name = "atividade_terraform"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg-atividade_terraform" {
  name                = "nsg_atividade_terraform-security-group"
  location            = azurerm_resource_group.rg-atividade_terraform.location
  resource_group_name = azurerm_resource_group.rg-atividade_terraform.name

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
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet-atividade_terraform" {
  name                = "atividade_terraform-network"
  location            = azurerm_resource_group.rg-atividade_terraform.location
  resource_group_name = azurerm_resource_group.rg-atividade_terraform.name
  address_space       = ["10.0.0.0/16"]
 
  tags = {
    environment = "Production"
  }
}


resource "azurerm_subnet" "subnet-atividade_terraform" {
  name                 = "atividade_terraform-subnet"
  resource_group_name  = azurerm_resource_group.rg-atividade_terraform.name
  virtual_network_name = azurerm_virtual_network.vnet-atividade_terraform.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_public_ip" "public-ip-atividade_terraform" {
  name                = "atividade_terraform_ip"
  resource_group_name = azurerm_resource_group.rg-atividade_terraform.name
  location            = azurerm_resource_group.rg-atividade_terraform.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic-atividade_terraform" {
  name                = "nic-atividade_terraform"
  location            = azurerm_resource_group.rg-atividade_terraform.location
  resource_group_name = azurerm_resource_group.rg-atividade_terraform.name

  ip_configuration {
    name                          = "ip-atividade_terraform"
    subnet_id                     = azurerm_subnet.subnet-atividade_terraform.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public-ip-atividade_terraform.id
  }
}



resource "azurerm_linux_virtual_machine" "vm-atividade_terraform" {
  name                = "vm-atividadeterraform"
  resource_group_name = azurerm_resource_group.rg-atividade_terraform.name
  location            = azurerm_resource_group.rg-atividade_terraform.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "@1Password!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic-atividade_terraform.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

resource "azurerm_network_interface_security_group_association" "nic-nsg-atividade_terraform" {
  network_interface_id      = azurerm_network_interface.nic-atividade_terraform.id
  network_security_group_id = azurerm_network_security_group.nsg-atividade_terraform.id
}

data "azurerm_public_ip" "ip-aula-terraform"{
    name = azurerm_public_ip.public-ip-atividade_terraform.name
    resource_group_name = azurerm_resource_group.rg-atividade_terraform.name  
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula-terraform.ip_address
    user = "adminuser"
    password = "@1Password!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }
  depends_on = [azurerm_linux_virtual_machine.vm-atividade_terraform
    
  ]
}

resource "null_resource" "upload-app" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula-terraform.ip_address
    user = "adminuser"
    password = "@1Password!"
  }

  provisioner "file" {
    source = "spring-petclinic-main"
    destination = "/home/adminuser"
  }
  depends_on = [azurerm_linux_virtual_machine.vm-atividade_terraform
    
  ]
}