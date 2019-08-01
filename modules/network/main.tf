resource "azurerm_dns_zone" "dns" {
  name                             = "${var.nw-dnsdomain}"
  resource_group_name              = "${var.nw-rsg}"
  registration_virtual_network_ids = ["${azurerm_virtual_network.vnet.id}"]
  #resolution_virtual_network_ids = ["${azurerm_virtual_network.vnet.id}"]
  zone_type = "Private"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.nw-name}"
  location            = "${var.nw-location}"
  address_space       = ["${var.nw-address_space}"]
  resource_group_name = "${var.nw-rsg}"
  dns_servers         = "${var.nw-dns_servers}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.nw-subnet_names[count.index]}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${var.nw-rsg}"
  address_prefix       = "${var.nw-subnet_prefixes[count.index]}"

  # network_security_group_id = "${azurerm_network_security_group.security_group.id}"
  count = "${length(var.nw-subnet_names)}"
}

module "azurerm_network_security_group" "security_group" {
  source       = "../nsg"
  nsg-name     = "${var.nw-name}-nsg"
  nsg-location = "${var.nw-location}"
  nsg-rsg      = "${var.nw-rsg}"
}

/*resource "azurerm_subnet_network_security_group_association" "link" {
  subnet_id                 = "${azurerm_subnet.subnet.id}"
  network_security_group_id = "${azurerm_network_security_group.security_group.id}"
}
resource "azurerm_network_watcher" "nw" {
  name                = "${var.nw-name}"
  location            = "${var.nw-location}"
  resource_group_name = "${var.nw-rsg}"
}*/

