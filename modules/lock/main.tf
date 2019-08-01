resource "azurerm_management_lock" "rglock" {
  name       = "${var.lock-name}"
  scope      = "${var.lock-scope}"
  lock_level = "${var.lock-level}"
  notes      = "This Resource is Read-Only"
}