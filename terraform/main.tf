provider "azurerm" {
  features {}
}

# get the image that was create by the packer script
data "azurerm_image" "web" {
  name                = "udacity-packer-image"
  resource_group_name = var.packer_resource_group
}

# create the resource group specificed by the user
resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Add a security rule for the VM's to receive HTTP data on port 8080.
  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# create network interfaces for the VM's
resource "azurerm_network_interface" "main" {
  count               = var.num_of_vms
  name                = "${var.prefix}-${count.index}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    primary                       = true
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }
}

# create a public IP for the Load Balancer
resource "azurerm_public_ip" "main" {
  name                = "lb-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}

resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_probe" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "http-server-probe"
  port                = 8080
}

resource "azurerm_lb_backend_address_pool" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "${var.prefix}-lb-backend-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.num_of_vms
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

// Create a rule for the LB to route traffic from the 80 port to the backend 8080 port on each VM
resource "azurerm_lb_rule" "main" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.main.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_availability_set" "main" {
  name                        = "${var.prefix}-aset"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  platform_fault_domain_count = 2
}


resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.num_of_vms
  name                            = "${var.prefix}-${count.index}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B1ls"
  admin_username                  = "ud-admin"
  admin_password                  = var.vm_password
  disable_password_authentication = false
  network_interface_ids = [element(azurerm_network_interface.main.*.id, count.index)]
  availability_set_id = azurerm_availability_set.main.id

  # use the image we sourced at the beginnng of the script.
  source_image_id = data.azurerm_image.web.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    environment = "dev",
    project-name  = "Deploying a Web Server in Azure"

  }
}

# create a virtual disk for each VM created.
resource "azurerm_managed_disk" "main" {
  count                           = var.num_of_vms
  name                            = "data-disk-${count.index}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  storage_account_type            = "Standard_LRS"
  create_option                   = "Empty"
  disk_size_gb                    = 1
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  count              = var.num_of_vms
  managed_disk_id    = azurerm_managed_disk.main.*.id[count.index]
  virtual_machine_id = azurerm_linux_virtual_machine.main.*.id[count.index]
  lun                = 10 * count.index
  caching            = "ReadWrite"
}

output "lb_url" {
  value       = "http://${azurerm_public_ip.main.ip_address}/"
  description = "This is the URL for the LB."
}