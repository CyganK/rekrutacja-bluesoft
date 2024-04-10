terraform {
    required_providers {
        azurerm = {
            source = "azurerm"
            version = "3.98.0"
        }
    }
}

provider "azurerm" {
  features {}
}
