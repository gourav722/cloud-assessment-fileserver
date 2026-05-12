environment         = "prod"
resource_group_name = "fileserver-prod-rg"
location            = "eastus"

# AKS — autoscaling enabled, bigger VM
cluster_name        = "fileserver-aks-prod"
kubernetes_version  = "1.29"
enable_auto_scaling = true
min_count           = 2
max_count           = 5
vm_size             = "Standard_D2s_v3"

# ACR — Standard SKU adds geo-replication support
acr_name            = "fileserverprodacr"
acr_sku             = "Standard"

# Storage
# azurefile-csi = Azure Files, ReadWriteMany
# Required for multi-replica so all pods share the same /data volume.
# Trade-off: higher latency than managed disk (~1–5ms vs ~0.5ms).
pvc_name            = "fileserver-pvc-prod"
storage_size        = "10Gi"
storage_class_name  = "azurefile-csi"

# App
service_port        = 8080
image_tag           = "1.0.0"
