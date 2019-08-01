resource "azurerm_network_interface" "nic" {
  name                = "${var.vm-name}-nic"
  location            = "${var.vm-location}"
  resource_group_name = "${var.vm-rsg}"

  ip_configuration {
    name                          = "${var.vm-name}-ipc"
    subnet_id                     = "${var.vm-subnet_id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                             = "${var.vm-name}"
  location                         = "${var.vm-location}"
  resource_group_name              = "${var.vm-rsg}"
  network_interface_ids            = ["${azurerm_network_interface.nic.id}"]
  vm_size                          = "${var.vm-size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.vm-name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.vm-name}"
    admin_username = "${var.vm-username}"
    admin_password = "${var.vm-password}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}
#https://gallery.technet.microsoft.com/OMS-Network-Performance-7ec93b2f/file/192741/1/EnableRules.ps1

resource "azurerm_virtual_machine_extension" "la-win" {
  name                       = "${var.vm-name}-la-ext"
  location                   = "${var.vm-location}"
  resource_group_name        = "${var.vm-rsg}"
  virtual_machine_name       = "${azurerm_virtual_machine.vm.name}"
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.vm-workspace_id}"
      }
    SETTINGS

  protected_settings = <<SETTINGS
  {
      "workspaceKey": "${var.vm-workspace_key}"
  }
  SETTINGS
}
