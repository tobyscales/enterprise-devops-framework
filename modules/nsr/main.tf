
resource "azurerm_network_security_group" "security_group" {
  name                = "${var.nsr-name}"
  resource_group_name = "${var.nsr-rsg}"
  network_security_group_name = "${var.nsr-nsg}"
}
