variable "sa-name" {
  description = "Name of the lock"
}
variable "sa-rsg" {
  description = "Pass the terraform id of the resource you wish to lock."
}
variable "sa-location" {
  description = "Type of lock to apply. Accepted values are: CanNotDelete and ReadOnly."
}
variable "sa-container" {
  description = "Name of container to deploy."
  default = "{substr(md5(var.sa-name),0,23)}"
}
variable "sa-container_access_type" {
  description = "Access Type of deployed container."
  default = "private"
}
variable "deploy-container" {
  type    = "string"
  default = "false"
}
