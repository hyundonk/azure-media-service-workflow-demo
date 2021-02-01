provider "azurerm" {
  version = "<=2.45.1"
  features {}
}

provider "azuread" {
}

terraform {
    backend "azurerm" {
    }
}


