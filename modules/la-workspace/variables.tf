variable "la-name" {
    description = "Name of the Log Analytics workspace"
}
variable "la-location" {
    description = "Location to deploy Log Analytics workspace"
    default ="East US" //the only place you can deploy this in the US
}
variable "la-rsg" {
    description = "Log Analytics Resource Group"
}
variable "do-deployment" {
    default=true
}
variable "la-retention" {
    description = "Number of days to keep data"
    default = "30"
}