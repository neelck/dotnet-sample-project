
# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "SaffronRestaurant-RG"
  location = "East US"
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "restaurant-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Static Public IP
resource "azurerm_public_ip" "pip" {
  name                = "restaurant-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" # Ensures the IP never changes
  sku                 = "Standard"
}

# Create nic and subnet
resource "azurerm_network_interface" "nic" {
  name                = "saffron-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "restaurant-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Network Security Group (Open Port 80 for HTTP)
resource "azurerm_network_security_group" "nsg" {
  name                = "restaurant-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
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
    name                       = "AllowRDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*" # STRONGLY RECOMMENDED: Change this to your Public IP
    destination_address_prefix = "*"
  }
}

# Create the VM
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "Saffron-VM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s" # Cost-effective for testing
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!" # Use a Secret in production!
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  # AUTOMATION: Installs IIS and .NET 9 Hosting Bundle on boot
  custom_data = base64encode(<<-EOF
    <powershell>
    # 1. Install IIS
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    
    # 2. Download and Install .NET 9 Hosting Bundle
    $dotnetUrl = "https://download.visualstudio.microsoft.com/download/pr/49961633-875b-4c07-b088-662867824141/008f1b674b01e3e7f45c2642730b2075/dotnet-hosting-9.0.1-win.exe"
    Invoke-WebRequest -Uri $dotnetUrl -OutFile "dotnet-hosting.exe"
    Start-Process -FilePath "dotnet-hosting.exe" -ArgumentList "/quiet /norestart" -Wait
    
    # 3. Restart IIS to apply changes
    iisreset
    </powershell>
  EOF
  )
}
