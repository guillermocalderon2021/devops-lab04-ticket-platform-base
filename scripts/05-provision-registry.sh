#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/04-prepare-terraform-files.sh"
terraform -chdir="$ROOT_DIR/terraform" init

# Primera fase: crea únicamente lo necesario para que GitHub Actions pueda
# publicar la imagen privada antes de crear el Container App.
terraform -chdir="$ROOT_DIR/terraform" apply -auto-approve \
  -target=azurerm_container_registry.main \
  -target=azurerm_role_assignment.github_acr_push \
  -target=azurerm_user_assigned_identity.api_pull \
  -target=azurerm_role_assignment.api_acr_pull

# Garantiza compatibilidad del pull por managed identity de Container Apps.
# shellcheck disable=SC1090
source "$ROOT_DIR/config/bootstrap.env"
az acr config authentication-as-arm update -r "$ACR_NAME" --status enabled >/dev/null

printf 'ACR y permisos iniciales preparados. Ya puede publicarse la imagen desde GitHub Actions.\n'
