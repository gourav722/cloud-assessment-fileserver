output "login_server" {
  value       = azurerm_container_registry.this.login_server
  description = "ACR login server URL (used to prefix image tags)"
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "acr_id" {
  value       = azurerm_container_registry.this.id
  description = "ACR resource ID — passed to AKS for AcrPull role assignment"
}
