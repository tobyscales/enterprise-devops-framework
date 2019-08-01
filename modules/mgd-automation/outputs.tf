output "id" {
    value = "${azurerm_automation_account.aa.id}"
}
output "aa-dsc_endpoint" {
    value = "${azurerm_automation_account.aa.dsc_server_endpoint}"
}
output "aa-dsc_key1" {
    value = "${azurerm_automation_account.aa.dsc_primary_access_key}"
}
output "aa-location" {
    value = "${azurerm_automation_account.aa.location}"
}