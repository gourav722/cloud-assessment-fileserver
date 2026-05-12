resource "helm_release" "this" {

  name = var.release_name

  chart = var.chart_path

  dependency_update = true

  set = [
    {
      name  = "image.repository"
      value = var.image_repository
    },
    {
      name  = "image.tag"
      value = var.image_tag
    },
    {
      name  = "existingPvc"
      value = var.pvc_name
    },
    {
      name  = "service.port"
      value = tostring(var.service_port)
    }
  ]
}
