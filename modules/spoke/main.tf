provider "azurerm" {
  alias           = "src"
}
provider "azurerm" {
  alias           = "dst"
}

module "network" {
  source             = "../network"
  nw-name            = "${var.spoke-name}"
  nw-rsg             = "${var.spoke-rsg}"
  nw-location        = "${var.spoke-location}"
  nw-dnsdomain       = "${var.nw-dnsdomain}"
  nw-address_space   = "${var.nw-address_space}"
  nw-subnet_prefixes = "${var.nw-subnet_prefixes}"
  nw-subnet_names    = "${var.nw-subnet_names}"
}

module "vnet-peer" {
  source              = "../vnet-peer"
  do-peering          = "${var.enable-peering}"
  destination-nw_name = "${var.hub-nw_name}"
  destination-nw_rsg  = "${var.hub-nw_rsg}"
  source-nw_name      = "${module.network.nw-name}"
  source-nw_rsg       = "${module.network.nw-rsg}"
  providers {
    azurerm.src = "azurerm.src"
    azurerm.dst = "azurerm.dst"
  }
}

data "azurerm_log_analytics_workspace" "la-workspace" {
  name                = "${var.la-workspace_name}"
  resource_group_name = "${var.la-workspace_rsg}"
  provider            = "azurerm.dst"
}

/*resource "azurerm_security_center_workspace" "security-workspace" {
  scope        = "${var.spoke-subid}"
  workspace_id = "${data.azurerm_log_analytics_workspace.la-workspace.id}"
}

resource "azurerm_security_center_subscription_pricing" "security-workspace-tier" {
  tier = "Standard"
}*/
