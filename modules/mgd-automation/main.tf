resource "azurerm_automation_account" "aa" {
  name                = "${var.aa-name}"
  location            = "${var.aa-location}" //only avaliable in west us 2
  resource_group_name = "${var.aa-rsg}"
  
  sku {
    name = "${var.aa-sku}"
  }
}

resource "azurerm_log_analytics_workspace_linked_service" "aa-to-la-link" {
  resource_group_name = "${var.la-rsg}"
  workspace_name      = "${var.la-name}"
  linked_service_name = "automation"

  linked_service_properties {
    resource_id = "${azurerm_automation_account.aa.id}"
  }
}
resource "azurerm_automation_credential" "credential" {
  name                = "FullAdmin"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
  account_name        = "${azurerm_automation_account.aa.name}"
  username            = "${var.aa-creduser}"
  password            = "${var.aa-credpass}"
  description         = "Default (Full Admin) Credential"
}
resource "azurerm_automation_runbook" "RBACAudit" {
  name                = "Invoke-AzureRmSubscriptionRBACAudit"
  location            = "${var.aa-location}"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
  account_name        = "${azurerm_automation_account.aa.name}"
  log_verbose         = "true"
  log_progress        = "true"
  description         = "Used to run periodic RBAC audits."
  runbook_type        = "PowerShellWorkflow"
  publish_content_link {
    uri = "https://gallery.technet.microsoft.com/scriptcenter/Audit-Azure-subscription-f57d114e/file/215387/1/Invoke-AzureRmSubscriptionRBACAudit.ps1"
  }
}

resource "azurerm_automation_module" "HybridRunbookWorkerDscModule" {
  name                    = "HybridRunbookWorkerDsc"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
  automation_account_name        = "${azurerm_automation_account.aa.name}"

  module_link = {
    uri = "https://devopsgallerystorage.blob.core.windows.net/packages/hybridrunbookworkerdsc.1.0.0.2.nupkg"

  }
}
#WorkspaceID
#WorkspaceKey
#AutomationEndpoint
#AutomationCredential
#detailed ref here: https://github.com/Azure/azure-quickstart-templates/tree/master/101-automation-configuration
resource "azurerm_automation_module" "xPSDesiredStateConfigurationModule" {
  name                    = "xPSDesiredStateConfiguration"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
  automation_account_name        = "${azurerm_automation_account.aa.name}"

  module_link = {
    uri = "https://devopsgallerystorage.blob.core.windows.net/packages/xpsdesiredstateconfiguration.8.4.0.nupkg"
  }
}
/*
resource "azurerm_automation_dsc_configuration" "Generic" {
  name                    = "test"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
 # account_name        = "${azurerm_automation_account.aa.name}"
  automation_account_name = "${azurerm_automation_account.aa.name}"
  location            = "${var.aa-location}" //only avaliable in west us 2
  content_embedded        = "configuration test {}"
}

resource "azurerm_automation_schedule" "one-time" {
  name                    = "tfex-automation_schedule-one_time"
  resource_group_name = "${azurerm_automation_account.aa.resource_group_name}"
  automation_account_name = "${azurerm_automation_account.aa.name}"
  frequency               = "OneTime"

  //defaults start_time to now + 7 min
}
*/