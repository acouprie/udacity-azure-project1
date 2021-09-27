provider "azurerm" {
  features {}
}

# get the image that was create by the packer script
data "azurerm_image" "web" {
  name                = "udacity-packer-image"
  resource_group_name = var.packer_resource_group
}

# Create the resource group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
}
# create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = "udacity1"
    environment = "development"
  }
}

# Create the subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create the network security group
resource "azurerm_network_security_group" "main" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = "udacity1"
    environment = "development"
  }
}

# Create security rules
resource "azurerm_network_security_rule" "rule1" {
    name                         = "DenyAllInbound"
    description                  = "This rule with low priority deny all the inbound traffic."
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Deny"
    protocol                     = "*"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefix        = "*"
    destination_address_prefix   = "*"
    resource_group_name          = azurerm_resource_group.main.name
    network_security_group_name  = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "rule2" {
    name                         = "AllowInboundInsideVN"
    description                  = "This rule allow the inbound traffic inside the same virtual network."
    priority                     = 101
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_ranges           = azurerm_virtual_network.main.address_space
    destination_port_ranges      = azurerm_virtual_network.main.address_space
    source_address_prefix        = "VirtualNetwork"
    destination_address_prefix   = "VirtualNetwork"
    resource_group_name          = azurerm_resource_group.main.name
    network_security_group_name  = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "rule3" {
    name                         = "AllowOutboundInsideVN"
    description                  = "This rule allow the outbound traffic inside the same virtual network."
    priority                     = 102
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_ranges           = azurerm_virtual_network.main.address_space
    destination_port_ranges      = azurerm_virtual_network.main.address_space
    source_address_prefix        = "VirtualNetwork"
    destination_address_prefix   = "VirtualNetwork"
    resource_group_name          = azurerm_resource_group.main.name
    network_security_group_name  = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "rule4" {
    name                         = "AllowHTTPFromLB"
    description                  = "This rule allow the HTTP traffic from the load balancer."
    priority                     = 103
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_ranges           = azurerm_virtual_network.main.address_space
    destination_port_ranges      = azurerm_virtual_network.main.address_space
    source_address_prefix        = "AzureLoadBalancer"
    destination_address_prefix   = "VirtualNetwork"
    resource_group_name          = azurerm_resource_group.main.name
    network_security_group_name  = azurerm_network_security_group.main.name
}

# Create network interface
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    project = "udacity1"
    environment = "development"
  }
}

# Create public IP
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    project = "udacity1"
    environment = "development"
  }
}

# Create load balancer
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

# The load balancer will use this backend pool
resource "azurerm_lb_backend_address_pool" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "${var.prefix}-lb-backend-pool"
}

# We associate the LB with the backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "main" {
  network_interface_id    = azurerm_network_interface.main.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# Create virtual machine availability set
resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-aset"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = "udacity1"
    environment = "development"
  }
}

# Create the virtual machines
resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.nb_vms
  name                            = "${var.prefix}-vm-${count.index}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B1ls"
  admin_username                  = "${var.username}"
  admin_password                  = "${var.password}"
  disable_password_authentication = false
  network_interface_ids = [element(azurerm_network_interface.main.*.id, count.index)]
  availability_set_id = azurerm_availability_set.main.id

  source_image_id = data.azurerm_image.web.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    project = "udacity1"
    environment = "development"
  }
}