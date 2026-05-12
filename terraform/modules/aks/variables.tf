variable "cluster_name" {
  type        = string
  description = "AKS cluster name"
}

variable "resource_group_name" {
  type        = string
  description = "Azure resource group (must already exist or be created by ACR module)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.29"
  description = "Kubernetes version to use on AKS"
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Fixed node count (used when auto-scaling is disabled)"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "VM SKU for the default node pool"
}

variable "enable_auto_scaling" {
  type        = bool
  default     = false
  description = "Enable cluster autoscaler on the default node pool"
}

variable "min_count" {
  type        = number
  default     = 1
  description = "Minimum node count when auto-scaling is enabled"
}

variable "max_count" {
  type        = number
  default     = 3
  description = "Maximum node count when auto-scaling is enabled"
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID — used to grant AcrPull role to AKS kubelet identity"
}
