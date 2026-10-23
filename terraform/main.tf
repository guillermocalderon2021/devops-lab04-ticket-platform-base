locals {
  prefix = "ticket-${var.name_suffix}"
  tags = {
    project     = "ticket-platform"
    environment = "initial"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.apply_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_user_assigned_identity" "api_pull" {
  name                = "id-${local.prefix}-acr-pull"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.api_pull.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_storage_account" "main" {
  name                     = "stticket${var.name_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

resource "azurerm_storage_container" "evidence" {
  name                  = "evidence"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${local.prefix}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = "ticketadmin"
  administrator_password = var.postgres_admin_password
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  backup_retention_days  = 7
  tags                    = local.tags
}

resource "azurerm_postgresql_flexible_server_database" "tickets" {
  name      = "tickets"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_container_app_environment" "main" {
  name                = "cae-${local.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${local.prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api_pull.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.api_pull.id
  }

  secret {
    name  = "db-password"
    value = var.postgres_admin_password
  }

  secret {
    name  = "storage-key"
    value = azurerm_storage_account.main.primary_access_key
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "ticket-api"
      image  = "${azurerm_container_registry.main.login_server}/${var.image_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env { name = "PORT" value = "3000" }
      env { name = "DATABASE_HOST" value = azurerm_postgresql_flexible_server.main.fqdn }
      env { name = "DATABASE_PORT" value = "5432" }
      env { name = "DATABASE_NAME" value = azurerm_postgresql_flexible_server_database.tickets.name }
      env { name = "DATABASE_USER" value = "ticketadmin" }
      env { name = "DATABASE_SSL" value = "true" }
      env { name = "DATABASE_PASSWORD" secret_name = "db-password" }
      env { name = "AZURE_STORAGE_ACCOUNT_NAME" value = azurerm_storage_account.main.name }
      env { name = "AZURE_STORAGE_ACCOUNT_KEY" secret_name = "storage-key" }
      env { name = "AZURE_STORAGE_CONTAINER_NAME" value = azurerm_storage_container.evidence.name }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [azurerm_role_assignment.api_acr_pull]
}

resource "azurerm_container_app" "frontend" {
  name                         = "ca-${local.prefix}-frontend"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api_pull.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.api_pull.id
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "ticket-frontend"
      image  = "${azurerm_container_registry.main.login_server}/${var.frontend_image_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "API_UPSTREAM"
        value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_role_assignment.api_acr_pull,
    azurerm_container_app.api
  ]
}
