environment         = "dev"
resource_group_name = "fileserver-dev-rg"
location            = "eastus"

# AKS
cluster_name        = "fileserver-aks-dev"
kubernetes_version  = "1.29"
node_count          = 1
vm_size             = "Standard_B2s"
enable_auto_scaling = false

# ACR — must be globally unique, alphanumeric only
acr_name            = "fileserverdevacr"
acr_sku             = "Basic"

# Storage
# managed-csi = Azure Managed Disk, ReadWriteOnce
# Fine for dev with 1 replica. Switch to azurefile-csi if you need RWX.
pvc_name            = "fileserver-pvc-dev"
storage_size        = "1Gi"
storage_class_name  = "managed-csi"

# App
service_port        = 8080
image_tag           = "latest"
