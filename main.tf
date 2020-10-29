resource random_id randomId {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.main.name
  }
  byte_length = 8
}

# Create a Public IP for the Virtual Machines
resource azurerm_public_ip ipspip01 {
  name                = "${random_id.randomId.hex}-ips-mgmt-pip01-delete-me"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource azurerm_storage_account ips_storageaccount {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_replication_type = "LRS"
  account_tier             = "Standard"

}

resource azurerm_network_interface ips01-mgmt-nic {
  name                = "${random_id.randomId.hex}-ips01-mgmt-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  enable_accelerated_networking = true
  enable_ip_forwarding          = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ips01mgmt
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.ipspip01.id
  }

}

resource azurerm_network_interface ips01-ext-nic {
  name                = "${random_id.randomId.hex}-ips01-ext-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  enable_accelerated_networking = true
  enable_ip_forwarding          = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.inspect_external.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ips01ext
    primary                       = true
  }

}

# internal network interface for ips vm
resource azurerm_network_interface ips01-int-nic {
  name                = "${random_id.randomId.hex}-ips01-int-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  enable_accelerated_networking = true
  enable_ip_forwarding          = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.inspect_internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ips01int
    primary                       = true
  }

}

# network interface for ips vm
resource azurerm_network_interface_security_group_association ips-ext-nsg {
  network_interface_id      = azurerm_network_interface.ips01-ext-nic.id
  network_security_group_id = azurerm_network_security_group.main.id
}
# network interface for ips vm
resource azurerm_network_interface_security_group_association ips-int-nsg {
  network_interface_id      = azurerm_network_interface.ips01-int-nic.id
  network_security_group_id = azurerm_network_security_group.main.id
}
# network interface for ips vm
resource azurerm_network_interface_security_group_association ips-mgmt-nsg {
  network_interface_id      = azurerm_network_interface.ips01-mgmt-nic.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# set up proxy config

data template_file vm_onboard {
  template = file("./ips-cloud-init.yaml")
  vars = {
    #gateway = gateway
    #nameservers = nameservers
  }
}

data template_cloudinit_config config {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.vm_onboard.rendered
  }
}

# ips01-VM
resource azurerm_linux_virtual_machine ips01-vm {
  name                = "${random_id.randomId.hex}-ips01-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  network_interface_ids = [azurerm_network_interface.ips01-mgmt-nic.id, azurerm_network_interface.ips01-ext-nic.id, azurerm_network_interface.ips01-int-nic.id]
  size                  = var.instanceType

  admin_username                  = var.adminUserName
  admin_password                  = var.adminPassword
  disable_password_authentication = false
  computer_name                   = "${random_id.randomId.hex}-ips01-vm"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = data.template_cloudinit_config.config.rendered

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.ips_storageaccount.primary_blob_endpoint
  }

}