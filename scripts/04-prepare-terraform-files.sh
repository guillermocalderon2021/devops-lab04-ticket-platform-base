#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/lab.env"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/bootstrap.env"

SECRETS_FILE="$ROOT_DIR/terraform/secrets.auto.tfvars"
[[ -f "$SECRETS_FILE" ]] || {
  echo "Falta terraform/secrets.auto.tfvars. Copie terraform/secrets.auto.tfvars.example y defina la contraseña." >&2
  exit 1
}

cat > "$ROOT_DIR/terraform/terraform.tfvars" <<TFVARS
subscription_id      = "$AZURE_SUBSCRIPTION_ID"
location             = "$AZURE_LOCATION"
name_suffix          = "$NAME_SUFFIX"
acr_name             = "$ACR_NAME"
image_name           = "$IMAGE_NAME"
frontend_image_name  = "$FRONTEND_IMAGE_NAME"
image_tag            = "$IMAGE_TAG"
apply_principal_id   = "$APPLY_PRINCIPAL_ID"
TFVARS

printf 'terraform/terraform.tfvars generado a partir de los archivos locales de configuración.\n'
