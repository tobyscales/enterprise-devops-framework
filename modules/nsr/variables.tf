variable "nsr-name" {
    description = "Name of the network"
}
variable "nsr-rsg" {
        description = "Resource group to deploy into"
}
variable "nsr-nsg" {
    description = "Use this NSG to deploy"
}

variable "priority" {

}
variable "direction" {

}
variable "access" {

}
variable "protocol" {
    default ="Tcp"
}
variable "source_port_range" {
    default = "*"
}
variable "destination_port_range" {
    default = "*"
}
variable "source_address_prefix" {
    default = "*"
}
variable "destination_address_prefix" {
    default = "*"
}