resource "kubernetes_persistent_volume_claim_v1" "this" {

  metadata {
    name = var.pvc_name
  }

  spec {
    # Empty string means "use cluster default" — works for kind and most managed clusters
    storage_class_name = var.storage_class_name == "" ? null : var.storage_class_name

    # RWO (ReadWriteOnce) works for single-replica deployments.
    # Switch to ReadWriteMany only with azurefile-csi or similar RWX-capable storage class.
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}
