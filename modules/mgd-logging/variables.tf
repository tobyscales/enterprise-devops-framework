variable "lm-name" {
    description = "Name of the Log Analytics workspace"
}
variable "lm-location" {
    description = "Location to deploy Log Analytics workspace"
    default ="East US" //the only place you can deploy this in the US
}
variable "lm-rsg" {
    description = "Log Analytics Resource Group"
}
variable "lm-retention" {
    description = "Number of days to keep data"
    default = "30"
}
variable "create-new-workspace" {
    default = true
}
locals {
    logdata-rg="${var.lm-name}"
}