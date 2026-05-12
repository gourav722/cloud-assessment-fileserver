terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }

  # Remote state in Azure Blob Storage.
  # Create the storage account once manually (or via a bootstrap script) before running apply.
  # az group create -n tfstate-rg -l eastus
  # az storage account create -n tfstatefileserver -g tfstate-rg --sku Standard_LRS
  # az storage container create -n tfstate --account-name tfstatefileserver
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatefileserver"
    container_name       = "tfstate"
    key                  = "fileserver.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ------------------------------------------------------------------
# Container Registry
# ------------------------------------------------------------------
module "acr" {
  source              = "../modules/acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  acr_name            = var.acr_name
  sku                 = var.acr_sku
}

# ------------------------------------------------------------------
# AKS Cluster
# (replaces modules/cluster which provisions kind for local dev)
# The helm/ and pvc/ modules below are IDENTICAL to the kind setup —
# only this block changes between local and cloud targets.
# ------------------------------------------------------------------
module "aks" {
  source              = "../modules/aks"
  cluster_name        = var.cluster_name
  resource_group_name = module.acr.resource_group_name
  location            = var.location
  kubernetes_version  = var.kubernetes_version
  node_count          = var.node_count
  vm_size             = var.vm_size
  enable_auto_scaling = var.enable_auto_scaling
  min_count           = var.min_count
  max_count           = var.max_count
  acr_id              = module.acr.acr_id
}

# ------------------------------------------------------------------
# Providers wired to AKS outputs
# Same provider config as the kind root — only the source of
# endpoint / certificates changes.
# ------------------------------------------------------------------
provider "kubernetes" {
  host                   = module.aks.endpoint
  client_certificate     = module.aks.client_certificate
  client_key             = module.aks.client_key
  cluster_ca_certificate = module.aks.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.aks.endpoint
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}

# ------------------------------------------------------------------
# Persistent Volume Claim  (REUSED module — cloud-agnostic)
# StorageClass differs per environment: see dev.tfvars / prod.tfvars
# ------------------------------------------------------------------
module "pvc" {
  source             = "../modules/pvc"
  pvc_name           = var.pvc_name
  storage_size       = var.storage_size
  storage_class_name = var.storage_class_name
}

# ------------------------------------------------------------------
# Helm Release  (REUSED module — cloud-agnostic)
# Image repository is now ACR-qualified instead of a local image name.
# ------------------------------------------------------------------
module "helm" {
  source           = "../modules/helm"
  depends_on       = [module.aks, module.pvc]
  release_name     = "fileserver-${var.environment}"
  chart_path       = "${path.root}/../../helm/fileserver"
  image_repository = "${module.acr.login_server}/fileserver"
  image_tag        = var.image_tag
  pvc_name         = var.pvc_name
  service_port     = var.service_port
}
