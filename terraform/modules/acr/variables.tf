variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
}

variable "location" {
  type        = string
  description = "Azure region (e.g. eastus)"
}

variable "acr_name" {
  type        = string
  description = "Globally unique ACR name (alphanumeric only)"
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "ACR SKU: Basic (dev) or Standard (prod)"
}
