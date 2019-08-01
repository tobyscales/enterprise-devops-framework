output "vnet_id" {
  value = "${module.network.vnet_id}"
}
output "subnet_ids" {
  value = ["${module.network.subnet_ids}"]
}
output "nw-name" {
  value = "${module.network.nw-name}"
}
output "workspace_id" {
    value = "${data.azurerm_log_analytics_workspace.la-workspace.id}"
}
output "workspace_key1" {
    value = "${data.azurerm_log_analytics_workspace.la-workspace.primary_shared_key}"
}