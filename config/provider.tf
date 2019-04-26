terraform {
  backend "azurerm" {}
}
provider azurerm {
  client_id     = "${var.clientids["${var.this-subalias}"]}"
  client_certificate_path = "${var.this-subalias}.pfx"
  client_certificate_password = "${var.this-certpass}"
  subscription_id = "${var.subs["${var.this-subalias}"]}"
  tenant_id       = "${var.tenantids["${var.this-subalias}"]}"
  version = ">= 1.0.0"
}

variable "this-subalias" {}
variable "this-certpass" {}
variable "subs" { type="map" }
variable "tenantids" { type="map"}
variable "clientids" { type="map"}
variable "certificates" { type="map" }
variable "keyvaults" { type="map"}
variable "keyvault_rgs" { type="map"}