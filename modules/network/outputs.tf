output "vnet_id" {
  value = "${azurerm_virtual_network.vnet.id}"
}
output "nw-name" {
  value = "${azurerm_virtual_network.vnet.name}"
}
output "nw-location" {
  value = "${azurerm_virtual_network.vnet.location}"
}
output "nw-rsg" {
  value = "${azurerm_virtual_network.vnet.resource_group_name}"
}
output "vnet_address_space" {
  value = "${azurerm_virtual_network.vnet.address_space}"
}
output "subnet_ids" {
  value = ["${azurerm_subnet.subnet.*.id}"]
}
output "subnet_names" {
  value = ["${azurerm_subnet.subnet.*.name}"]
}
output "subnet_addresses" {
  value = ["${azurerm_subnet.subnet.*.address_prefix}"]
}
output "dns_id" {
  value = "${azurerm_dns_zone.dns.id}"
}
output "dnsdomain" {
  value = "${azurerm_dns_zone.dns.name}"
}
output "name_servers" {
  value = "${azurerm_dns_zone.dns.name_servers}"
}