
resource "azurerm_key_vault" "kv" {
  name                        = "${var.kv-name}"
  location                    = "${var.kv-location}"
  resource_group_name         = "${var.kv-rsg}"
  enabled_for_disk_encryption = true
  tenant_id                   = "${var.kv-tenant_id}"

  sku {
    name = "standard"
  }
}