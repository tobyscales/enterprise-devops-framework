output "workspace_id" {
    value = "${azurerm_log_analytics_workspace.la.workspace_id}"
}
output "id" {
    value = "${azurerm_log_analytics_workspace.la.id}"
}
output "workspace_name" {
    value = "${azurerm_log_analytics_workspace.la.name}"
}
output "key1" {
    value = "${azurerm_log_analytics_workspace.la.primary_shared_key}"
}
output "rsg" {
    value = "${azurerm_log_analytics_workspace.la.resource_group_name}"
}