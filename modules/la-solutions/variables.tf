variable "la-workspace_name" {
    description = "Name of the Log Analytics workspace"
}
variable "la-location" {
    description = "Location to deploy Log Analytics workspace"
    default ="East US" //the only place you can deploy this in the US
}
variable "la-rsg" {
    description = "Log Analytics Resource Group"
}
variable "la-resource_id" {
    description = "Log Analytics Resource ID"
}