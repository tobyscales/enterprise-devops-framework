variable "spoke-name" {
    description = "Root name of the spoke"
}
variable "spoke-location" {
    description = "Location to deploy"
}
variable "spoke-rsg" {
        description = "Resource group to deploy into"
}
variable "enable-peering" {
  default = "0"
}
variable "hub-nw_rsg" {
  description ="default"
}
variable "hub-nw_name" {
  description ="default"
}
variable "nw-address_space" {
  description = "The address space that is used by the spoke's virtual network."
  default     = "10.0.0.0/16"
}
# If no values specified, this defaults to Azure DNS 
variable "nw-dns_servers" {
  description = "The DNS servers to be used with vNet"
  default     = []
}
variable "nw-dnsdomain" {
  description = "The DNS servers to be used with vNet"
}
variable "nw-subnet_prefixes" {
  description = "The address prefix to use for the subnet."
  default     = ["10.0.1.0/24"]
}
variable "la-workspace_rsg" {
}
variable "la-workspace_name" {
}
variable "nw-subnet_names" {
  description = "A list of public subnets inside the vNet."
  default     = ["subnet1"]
}

