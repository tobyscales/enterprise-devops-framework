terraform {
  #backend "azurerm" {}
}
provider azurerm {
  client_id     = "${var.this-config["client_id"]}"
  client_certificate_path = "${var.this-config["subalias"]}.${var.username}.pfx"
  client_certificate_password = "${var.this-certpass}"
  subscription_id = "${var.this-config["subscription_id"]}"
  tenant_id       = "${var.this-config["tenant_id"]}"
  version = ">= 1.0.0"
}
variable "username" { }
variable "this-certpass" {}
variable "this-config" { type="map" }