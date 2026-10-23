#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/lab.env"

for cmd in az terraform gh git docker node npm; do
  command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

[[ -f "$CONFIG_FILE" ]] || {
  echo "Falta $CONFIG_FILE. Copie config/lab.env.example como config/lab.env y complete sus valores." >&2
  exit 1
}

# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${AZURE_LOCATION:?Defina AZURE_LOCATION en config/lab.env}"
: "${GITHUB_REPOSITORY:?Defina GITHUB_REPOSITORY en config/lab.env}"
: "${IMAGE_NAME:?Defina IMAGE_NAME en config/lab.env}"
: "${FRONTEND_IMAGE_NAME:?Defina FRONTEND_IMAGE_NAME en config/lab.env}"
: "${IMAGE_TAG:?Defina IMAGE_TAG en config/lab.env}"

az account show >/dev/null
gh auth status >/dev/null

printf 'Herramientas, archivo de configuración y sesiones verificadas.\n'
az account show --query '{subscription:id,name:name,tenant:tenantId,user:user.name}' -o table
printf 'Región configurada: %s\n' "$AZURE_LOCATION"
printf 'Repositorio GitHub: %s\n' "$GITHUB_REPOSITORY"
