output "api_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "frontend_hostname" {
  value = azurerm_container_app.frontend.ingress[0].fqdn
}

output "container_registry_name" {
  value = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "postgres_host" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}
