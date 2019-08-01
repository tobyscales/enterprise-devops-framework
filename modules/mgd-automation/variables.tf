variable "aa-name" {
    description = "Name of the automation account"
}
variable "aa-location" {
    description = "Location to deploy automation account"
    default = "West US 2"
}
variable "aa-sku" {
    description = "Automation sku; acceptable values are Basic and Standard"
    default = "Basic"
}
variable "aa-rsg" {
    description = "Automation Resource Group"
}
variable "aa-creduser" {
    description = "Azure Automcation Credential User"
}
variable "aa-credpass" {
    description = "Azure Automcation Credential Password"
}
variable "la-name" {
    description = "Name of the Log Analytics workspace to link to"
}
variable "la-rsg" {
    description = "Log Analytics Linked Service Resource Group"
}