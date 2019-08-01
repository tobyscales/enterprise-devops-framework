module "resource_group" {
  source      = "../resource-group"
  rg-name     = "${var.lm-name}"
  rg-location = "${var.lm-location}"
}

module "la-workspace" {
  source        = "../la-workspace"
  la-name       = "${var.lm-name}"
  la-location   = "${var.lm-location}"
  la-rsg        = "${module.resource_group.rg-name}"
  do-deployment = "${var.create-new-workspace}"
}

module "la-solutions" {
  source            = "../la-solutions"
  la-workspace_name = "${module.la-workspace.workspace_name}"
  la-resource_id    = "${module.la-workspace.id}"
  la-rsg            = "${module.resource_group.rg-name}"
  la-location       = "${var.lm-location}"
}

module "log_storage" {
  source      = "../storage-acct"
  sa-name     = "${substr(md5(var.lm-name),0,23)}"
  sa-rsg      = "${module.resource_group.rg-name}"
  sa-location = "${var.lm-location}"
}

/* NOT WORKING 11-27-2018 due to requirement of datasource to live under/workspaces (not a primary rp)
resource "azurerm_template_deployment" "datasource" {
  name                = "dataSourceDeployment"
  resource_group_name = "${module.resource_group.rg-name}"

  template_body = <<DEPLOY
      {
  "name": "string",
  "type": "Microsoft.OperationalInsights/workspaces",
  "apiVersion": "2015-11-01-preview",
  "location": "string",
  "tags": {},
  "properties": {
    "source": "string",
    "customerId": "string",
    "portalUrl": "string",
    "sku": {
      "name": "string"
    },
    "retentionInDays": "integer"
  },
  "resources": [
    {
        "name": "AzureActivityLog",
        "type": "dataSources",
        "apiVersion": "2015-11-01-preview",
        "tags": {},
        "properties": { "linkedResourceId": "[concat(subscription().id, '/providers/Microsoft.Insights/eventTypes/management')]"},
        "kind": "AzureActivityLog"
      }
  ]
      }
DEPLOY
  # these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    #"storageAccountType" = "Standard_GRS"
  }

  deployment_mode = "Incremental"
}

resource "azurerm_monitor_log_profile" "az-activity" {
  name = "${var.lm-name}-actlog"

  categories = [
    "Action",
    "Delete",
    "Write",
  ]

  locations = [
    "global",
    "eastus",
    "eastus2",
    "westus2",
    "westus",
  ]

  # RootManageSharedAccessKey is created by default with listen, send, manage permissions
  #servicebus_rule_id = "${azurerm_eventhub_namespace.test.id}/authorizationrules/RootManageSharedAccessKey"
  #storage_account_id = "${azurerm_storage_account.logstore.id}"
  storage_account_id = "${module.log_storage.id}"

  retention_policy {
    enabled = true
    days    = 7
  }
}*/

/* NOT WORKING 11-2018 resource "azurerm_log_analytics_solution" "ServiceMap" {
  solution_name         = "ServiceMap"
  location              = "${var.lm-location}"
  resource_group_name   = "${module.resource_group.rg-name}"
  workspace_resource_id = "${module.la-workspace.id}"
  workspace_name        = "${module.la-workspace.workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ServiceMap"
  }
}*/


/* NOT WORKING 11-2018 resource "azurerm_log_analytics_solution" "WireData2" {
  solution_name         = "WireData2"
  location              = "${var.lm-location}"
  resource_group_name   = "${module.resource_group.rg-name}"
  workspace_resource_id = "${module.la-workspace.id}"
  workspace_name        = "${module.la-workspace.workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/WireData2"
  }
}*/


/*resource "azurerm_log_analytics_solution" "Start-Stop-VM" {
  solution_name         = "Start-Stop-VM"
  location              = "${var.lm-location}"
  resource_group_name   = "${module.resource_group.rg-name}"
  workspace_resource_id = "${module.la-workspace.id}"
  workspace_name        = "${module.la-workspace.workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Start-Stop-VM"
  }
}

resource "azurerm_log_analytics_solution" "Security" {
  solution_name         = "Security(${module.la-workspace.workspace_name})"
  location              = "${var.lm-location}"
  resource_group_name   = "${module.resource_group.rg-name}"
  workspace_resource_id = "${module.la-workspace.id}"
  workspace_name        = "${module.la-workspace.workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }
}
resource "azurerm_log_analytics_solution" "ChangeTracking" {
  solution_name         = "ChangeTracking(${module.la-workspace.workspace_name})"
  location              = "${var.lm-location}"
  resource_group_name   = "${module.resource_group.rg-name}"
  workspace_resource_id = "${module.la-workspace.id}"
  workspace_name        = "${module.la-workspace.workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ChangeTracking"
  }
}*/

