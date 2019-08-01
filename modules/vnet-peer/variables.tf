variable "destination-nw_name" {
    description = "Destination network name"
}
variable "destination-nw_rsg" {
        description = "Resource group name of destination network"
}
variable "do-peering" {
    default=1
}
variable "peering-name" {
    default="net-peer"
}
variable "source-nw_name" {
    description = "Source network name"
}
variable "source-nw_rsg" {
        description = "Resource group to deploy into"
}
