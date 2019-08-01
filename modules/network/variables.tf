variable "nw-name" {
    description = "Name of the network"
}
variable "nw-location" {
    description = "Location to deploy"
}
variable "nw-rsg" {
        description = "Resource group to deploy into"
}
variable "nw-address_space" {
  description = "The address space that is used by the virtual network."
  default     = "10.0.0.0/22"
}

# If no values specified, this defaults to Azure DNS 
variable "nw-dns_servers" {
  description = "The DNS servers to be used with vNet"
  default     = []
}
variable "nw-dnsdomain" {
  description = "AzureDNS Private Domain"
}

variable "nw-subnet_prefixes" {
  description = "The address prefix to use for the subnet."
  default     = ["10.0.0.0/25", "10.0.0.128/25", "10.0.1.0/24"]
}

variable "nw-subnet_names" {
  description = "A list of public subnets inside the vNet."
  default     = ["gw-dmz","front-end", "back-end"]
}
