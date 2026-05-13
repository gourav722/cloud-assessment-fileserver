terraform {

  required_version = ">= 1.5.0"

  required_providers {

    kind = {
      source = "tehcyx/kind"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }

    null = {
      source = "hashicorp/null"
    }
  }
}

module "cluster" {

  source = "./modules/cluster"

  cluster_name = var.cluster_name
}

resource "null_resource" "load_image" {

  depends_on = [module.cluster]

  triggers = {
    cluster_name = var.cluster_name
    image_tag    = "latest"
  }

  provisioner "local-exec" {

    command = "kind load docker-image fileserver:latest --name ${var.cluster_name}"
  }
}

provider "kubernetes" {

  host = module.cluster.endpoint

  client_certificate = module.cluster.client_certificate

  client_key = module.cluster.client_key

  cluster_ca_certificate = module.cluster.cluster_ca_certificate
}

provider "helm" {

  kubernetes = {

    host = module.cluster.endpoint

    client_certificate = module.cluster.client_certificate

    client_key = module.cluster.client_key

    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

module "pvc" {

  source = "./modules/pvc"

  pvc_name = var.pvc_name

  storage_size = var.storage_size
}

module "helm" {

  source = "./modules/helm"

  depends_on = [null_resource.load_image]

  release_name = "fileserver-${var.environment}"

  chart_path = "${path.root}/../helm/fileserver"

  image_repository = "fileserver"

  image_tag = "latest"

  pvc_name = var.pvc_name

  service_port = var.service_port
}