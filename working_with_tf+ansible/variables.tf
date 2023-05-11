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
  default = "4e3137f5-801e-4ca9-b7e9-6c979ed03c8d"
}

variable "ARM_TENANT_ID" {
  type    = string
  default = "2954b8c5-adeb-42af-9b9b-607bb0d701aa"
}

variable "ARM_CLIENT_ID" {
  type    = string
  default = "cb238434-7460-4311-9897-fa24e0f095fc"
}

variable "ARM_CLIENT_SECRET" {
  type    = string
  default = "u2n8Q~jDK6aY5adzK7_8JCo-OU.gkl8HKQvBNbL1"
}

variable "vm_names" {
  type = list(string)
  default = ["Postgresql1", "Postgresql2", "Flask", "LB-database", "Monitoring", "AnsibleVM"]
}

