output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "sp_app_id" {
  value = azuread_application.github_actions_app.application_id
}

output "sp_password" {
  value     = azuread_service_principal_password.github_actions_password.value
  sensitive = true
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
