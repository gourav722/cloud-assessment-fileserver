variable "pvc_name" {
  type        = string
  description = "Name of the PersistentVolumeClaim"
}

variable "storage_size" {
  type        = string
  description = "Requested storage size (e.g. 1Gi)"
}

variable "storage_class_name" {
  type        = string
  default     = ""
  description = "StorageClass to use. Empty string uses the cluster default (works for kind). Use managed-csi for Azure RWO or azurefile-csi for Azure RWX."
}
