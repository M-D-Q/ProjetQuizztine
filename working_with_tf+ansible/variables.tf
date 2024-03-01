variable "resource_group_location" {
  type        = string
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "ARM_SUBSCRIPTION_ID" {
  type    = string
  default = "................."
}

variable "ARM_TENANT_ID" {
  type    = string
  default = "..............."
}

variable "ARM_CLIENT_ID" {
  type    = string
  default = "................"
}

variable "ARM_CLIENT_SECRET" {
  type    = string
  default = "................"
}

variable "vm_names" {
  type = list(string)
  default = ["Postgresql1", "Postgresql2", "Flask", "LB-database", "Monitoring", "AnsibleVM"]
}

