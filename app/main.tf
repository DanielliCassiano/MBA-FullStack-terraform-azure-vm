terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {

  features {}
}

resource "azurerm_resource_group" "rg-aulaInfra" {
  name     = "aulaInfraCloudTerra"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet-aulaInfra" {
  name                = "vNet"
  location            = azurerm_resource_group.rg-aulaInfra.location
  resource_group_name = azurerm_resource_group.rg-aulaInfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Class"
    turma = "FS04"
    faculdade = "Impacta"
    professor = "João"
  }
}

resource "azurerm_subnet" "Sub-aulaInfra" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-aulaInfra.name
  virtual_network_name = azurerm_virtual_network.vnet-aulaInfra.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_public_ip" "ip-aulaInfra" {
  name                    = "ip-aula"
  location                = azurerm_resource_group.rg-aulaInfra.location
  resource_group_name     = azurerm_resource_group.rg-aulaInfra.name
  allocation_method       = "Static"

  tags = {
    environment = "test"
  }
}



resource "azurerm_network_security_group" "nsc-aulaInfra" {
  name                = "nsc-aula"
  location            = azurerm_resource_group.rg-aulaInfra.location
  resource_group_name = azurerm_resource_group.rg-aulaInfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
          name                       = "Web"
          priority                   = 1001
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
      }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-aulaInfra" {
  name                = "nic"
  location            = azurerm_resource_group.rg-aulaInfra.location
  resource_group_name = azurerm_resource_group.rg-aulaInfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.Sub-aulaInfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ip-aulaInfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-association-aulaInfra" {
  network_interface_id      = azurerm_network_interface.nic-aulaInfra.id
  network_security_group_id = azurerm_network_security_group.nsc-aulaInfra.id
}

resource "azurerm_storage_account" "saaulainfra" {
  name                     = "storageaulainfrasafe"
  resource_group_name      = azurerm_resource_group.rg-aulaInfra.name
  location                 = azurerm_resource_group.rg-aulaInfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_linux_virtual_machine" "vm-aulaInfra" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.rg-aulaInfra.name
  location            = "brazilsouth"
  size                = "Standard_E2bs_v5"
  network_interface_ids = [
    azurerm_network_interface.nic-aulaInfra.id
  ]

  admin_username      = var.user
  admin_password      = var.password
  disable_password_authentication = false

source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
}
  os_disk {
    name                 = "myDisk"
    caching              = "ReadWrite"
    storage_account_type     = "Premium_LRS"
  }

    boot_diagnostics {
      storage_account_uri = azurerm_storage_account.saaulainfra.primary_blob_endpoint
    }

    depends_on = [ azurerm_resource_group.rg-aulaInfra ]
}

variable "user" {
    description = "usuario da máquina"
    type = string
  
}

variable "password" {
    
}

data "azurerm_public_ip" "ip-aula"{
    name = azurerm_public_ip.ip-aulaInfra.name
    resource_group_name = azurerm_resource_group.rg-aulaInfra.name
}

resource "null_resource" "install-webserver" {
 
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = var.user
    password = var.password
  }

  provisioner "remote-exec" {
    
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }
  depends_on = [
    azurerm_linux_virtual_machine.vm-aulaInfra
  ]
}

resource "null_resource" "upload-app" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = var.user
    password = var.password
  }

  provisioner "file" {
    source = "app"
    destination = "/home/adminuser"
  }

   depends_on = [
    azurerm_linux_virtual_machine.vm-aulaInfra
  ]
}
