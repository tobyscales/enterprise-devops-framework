provider "azurerm" {
  alias           = "src"
}
provider "azurerm" {
  alias           = "dst"
}

data "azurerm_virtual_network" "destination" {
  name                = "${var.destination-nw_name}"
  resource_group_name = "${var.destination-nw_rsg}"
  provider            = "azurerm.dst"
}

resource "azurerm_virtual_network_peering" "vnet-peer" {
  name                         = "${var.peering-name}"
  resource_group_name          = "${var.source-nw_rsg}"
  virtual_network_name         = "${var.source-nw_name}"
  remote_virtual_network_id    = "${data.azurerm_virtual_network.destination.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  count                        = "${var.do-peering}"
  provider            = "azurerm.src"
}
