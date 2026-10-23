#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/04-prepare-terraform-files.sh"
terraform -chdir="$ROOT_DIR/terraform" init
terraform -chdir="$ROOT_DIR/terraform" apply -auto-approve

API_URL=$(terraform -chdir="$ROOT_DIR/terraform" output -raw api_url)
FRONTEND_HOST=$(terraform -chdir="$ROOT_DIR/terraform" output -raw frontend_hostname)

printf '\nAplicación inicial desplegada.\n'
printf 'API: %s\n' "$API_URL"
printf 'Frontend: https://%s\n' "$FRONTEND_HOST"
