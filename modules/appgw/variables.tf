variable "appgw-name" {
    description = "Name of the App Gateway"
}
variable "appgw-rsg" {
    description = "App Gateway Resource Group"
}
variable "appgw-location" {
    description = "Location to deploy App Gateway"
    default = "West US 2"
}
variable "appgw-sku-name" {
    description = "App Gateway sku; acceptable values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, WAF_v2"
    default = "Standard_Small"
}
variable "appgw-sku-tier" {
    description = "App Gateway tier; acceptable values are Standard, Standard_v2, WAF, WAF_v2"
    default = "Standard"
}
variable "appgw-sku-capacity" {
    description = "Specifies instance count. Can be 1 to 10."
    default = "1"
}
variable "appgw-gw-vnet_id" {
    description = "No other resource can be deployed in a subnet where Application Gateway is deployed."
}
variable "appgw-gw-subnet_name" {
    description = "No other resource can be deployed in a subnet where Application Gateway is deployed."
}
variable "appgw-feport" {
    description = "Port number"
}
variable "appgw-fe-subnet_id" {
    description = "ID of front-end subnet"
}
variable "appgw-be-addr_fqdn" {
    description = "FQDN for backend pool"
    default = []
}

/*variable "appgw-feip_id" {
    description = "ID of Public IP Address. Should be Dynamic."
}*/