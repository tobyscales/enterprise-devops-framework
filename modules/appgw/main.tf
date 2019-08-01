resource "azurerm_public_ip" "appgw-pip" {
  name                         = "${var.appgw-name}-pip"
  location                     = "${var.appgw-location}"
  resource_group_name          = "${var.appgw-rsg}"
  public_ip_address_allocation = "dynamic"
}
resource "azurerm_application_gateway" "appgw" {
  name                = "${var.appgw-name}"
  resource_group_name = "${var.appgw-rsg}"
  location            = "${var.appgw-location}"

  sku {
    name     = "${var.appgw-sku-name}"
    tier     = "${var.appgw-sku-tier}"
    capacity = "${var.appgw-sku-capacity}"
  }

  gateway_ip_configuration {
    name      = "${var.appgw-name}-gwip"
    subnet_id = "${var.appgw-gw-vnet_id}/subnets/${var.appgw-gw-subnet_name}"
  }

  frontend_port {
    name = "${var.appgw-name}-feport"
    port = "${var.appgw-feport}"
  }

  frontend_ip_configuration {
    name                 = "${var.appgw-name}-feip"
    public_ip_address_id = "${azurerm_public_ip.appgw-pip.id}"
  }

  backend_address_pool {
    name = "${var.appgw-name}-beap"
    fqdn_list = ["${var.appgw-be-addr_fqdn}"]
  }

  backend_http_settings {
    name                  = "${var.appgw-name}-be-htst"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "${var.appgw-name}-httplstn"
    frontend_ip_configuration_name = "${var.appgw-name}-feip"
    frontend_port_name             = "${var.appgw-name}-feport"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.appgw-name}-rqrt"
    rule_type                  = "Basic"
    http_listener_name         = "${var.appgw-name}-httplstn"
    backend_address_pool_name  = "${var.appgw-name}-beap"
    backend_http_settings_name = "${var.appgw-name}-be-htst"
  }

  /* Path-based routing example
  http_listener {
    name                           = "${azurerm_virtual_network.vnet.name}-httplstn-pbr.contoso.com"
    host_name                      = "pbr.contoso.com"
    frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
    frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
    protocol                       = "Http"
  }

  backend_address_pool {
    name = "${azurerm_virtual_network.vnet.name}-beap-fallback"
  }

  backend_address_pool {
    name = "${azurerm_virtual_network.vnet.name}-beap-first"
  }

  backend_address_pool {
    name = "${azurerm_virtual_network.vnet.name}-beap-second"
  }

  request_routing_rule {
    name               = "${azurerm_virtual_network.vnet.name}-rqrt"
    rule_type          = "PathBasedRouting"
    http_listener_name = "${azurerm_virtual_network.vnet.name}-httplstn-pbr.contoso.com"
    url_path_map_name  = "pbr.contoso.com"
  }

  url_path_map {
    name                               = "pbr.contoso.com"
    default_backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap-fallback"
    default_backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"

    path_rule {
      name                       = "pbr.contoso.com_first"
      paths                      = ["/first/*"]
      backend_address_pool_name  = "${local.awg_clusters_name}-beap-first"
      backend_http_settings_name = "${local.awg_clusters_name}-be-htst"
    }

    path_rule {
      name                       = "pbr.contoso.com_second"
      paths                      = ["/second/*"]
      backend_address_pool_name  = "${local.awg_clusters_name}-beap-second"
      backend_http_settings_name = "${local.awg_clusters_name}-be-htst"
    }
  }*/
}
