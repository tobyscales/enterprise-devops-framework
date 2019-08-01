
resource "azurerm_network_security_group" "security_group" {
  name                = "${var.nsg-name}"
  location            = "${var.nsg-location}"
  resource_group_name = "${var.nsg-rsg}"
}
