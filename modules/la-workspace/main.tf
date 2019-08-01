resource "azurerm_log_analytics_workspace" "la" {
  name                = "${var.la-name}"
  location            = "${var.la-location}"
  resource_group_name = "${var.la-rsg}"
  sku                 = "PerNode"
  retention_in_days   = "${var.la-retention}"
  #count               = "${var.do-deployment}"
}
