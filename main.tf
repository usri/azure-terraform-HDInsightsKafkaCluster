terraform {
  backend "remote" {
    organization = "zambrana"

    workspaces {
      name = "work-BTS-SWIM-DataIngestion-Cluster"
    }
  }
  required_version = ">= 0.12.17"
}

provider "azurerm" {
  version = "=1.37.0"
}
resource "azurerm_resource_group" "genericRG" {
  name     = "${var.suffix}${var.rgName}"
  location = var.location
  tags     = var.tags
}
