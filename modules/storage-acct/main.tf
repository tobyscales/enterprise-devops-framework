resource "azurerm_storage_account" "storage" {
  name                     = "${var.sa-name}"
  resource_group_name      = "${var.sa-rsg}"
  location                 = "${var.sa-location}"
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "test" {
  name                  = "${var.sa-container}"
  count = "${var.deploy-container == "true" ? 1 : 0}"
  resource_group_name   = "${var.sa-rsg}"
  storage_account_name  = "${var.sa-name}"
  container_access_type = "${var.sa-container_access_type}"
}
data "azurerm_storage_account" "storaged" {
  name                = "${var.sa-name}"
  resource_group_name = "${var.sa-rsg}"
  depends_on          = ["azurerm_storage_account.storage"]
}
