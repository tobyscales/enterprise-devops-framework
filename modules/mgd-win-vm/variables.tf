variable "vm-name" {
    description = "Name of the virtual machine"
}
variable "vm-location" {
    description = "Location to deploy virtual machine"
}
variable "vm-rsg" {
    description = "Resource group for the virtual machine"
}
variable "vm-size" {
    description = "VM Sku size"
}
variable "vm-username" {
    description = "Username"
    default = "local-adm"
}
variable "vm-password" {
    description = "Password"
    default = "S00perS3kr!t12345"
}
variable "vm-subnet_id" {
    description = "Subnet ID for the virtual machine"
}
variable "vm-workspace_id" {
    description = "Workspace ID for the virtual machine"
}
variable "vm-workspace_key" {
    description = "Workspace Key for the virtual machine"
}
variable "vm-dsc_url" {
    description = "e"
}variable "vm-dsc_config" {
    description = "virtual machine"
}variable "vm-dsc_key1" {
    description = "Key for DSC environment"
}