output "api_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "frontend_hostname" {
  value = azurerm_static_web_app.frontend.default_host_name
}

output "static_web_app_api_key" {
  value     = azurerm_static_web_app.frontend.api_key
  sensitive = true
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
