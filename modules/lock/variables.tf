variable "lock-name" {
    description = "Name of the lock"
}
variable "lock-scope" {
    description = "Pass the terraform id of the resource you wish to lock."
}

variable "lock-level" {
    description = "Type of lock to apply. Accepted values are: CanNotDelete and ReadOnly."
}