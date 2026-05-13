variable "environment" {
  type        = string
  description = "Deployment environment label (dev or prod)"
}

variable "resource_group_name" {
  type        = string
  description = "Azure resource group name"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "cluster_name" {
  type        = string
  description = "AKS cluster name"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "enable_auto_scaling" {
  type    = bool
  default = false
}

variable "min_count" {
  type    = number
  default = 1
}

variable "max_count" {
  type    = number
  default = 3
}

variable "acr_name" {
  type        = string
  description = "Globally unique ACR name (alphanumeric, no hyphens)"
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "pvc_name" {
  type = string
}

variable "storage_size" {
  type = string
}

variable "storage_class_name" {
  type        = string
  default     = "managed-csi"
  description = "managed-csi for RWO (single replica), azurefile-csi for RWX (multi replica)"
}

variable "service_port" {
  type    = number
  default = 8080
}

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy (commit SHA or semver)"
}
