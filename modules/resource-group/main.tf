resource "azurerm_resource_group" "rsg" {
    name = "${var.rg-name}"
    location = "${var.rg-location}"
}