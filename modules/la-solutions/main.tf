resource "azurerm_log_analytics_solution" "AzureActivity" {
  solution_name         = "AzureActivity"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AzureActivity"
  }
}

resource "azurerm_log_analytics_solution" "AgentHealthAssessment" {
  solution_name         = "AgentHealthAssessment"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AgentHealthAssessment"
  }
}

resource "azurerm_log_analytics_solution" "AntiMalware" {
  solution_name         = "AntiMalware"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AntiMalware"
  }
}

resource "azurerm_log_analytics_solution" "KeyVaultAnalytics" {
  solution_name         = "KeyVaultAnalytics"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/KeyVaultAnalytics"
  }
}

resource "azurerm_log_analytics_solution" "NetworkMonitoring" {
  solution_name         = "NetworkMonitoring"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/NetworkMonitoring"
  }
}

resource "azurerm_log_analytics_solution" "AzureAutomation" {
  solution_name         = "AzureAutomation"
  location              = "${var.la-location}"
  resource_group_name   = "${var.la-rsg}"
  workspace_resource_id = "${var.la-resource_id}"
  workspace_name        = "${var.la-workspace_name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AzureAutomation"
  }
}