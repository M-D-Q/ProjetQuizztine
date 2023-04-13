terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.51.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}


provider "azurerm" {
    # Configuration options
  features {}

subscription_id = "<Your-Subscription Id>"
tenant_id       = "<Your-Tenant-Id>"
client_id       = "<Your-Client-Id>"
client_secret   = "<Your-Client-Secret>"
}
