#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/04-prepare-terraform-files.sh"
terraform -chdir="$ROOT_DIR/terraform" init
terraform -chdir="$ROOT_DIR/terraform" apply -auto-approve

API_URL=$(terraform -chdir="$ROOT_DIR/terraform" output -raw api_url)
SWA_TOKEN=$(terraform -chdir="$ROOT_DIR/terraform" output -raw static_web_app_api_key)

cat > "$ROOT_DIR/frontend/.env.production.local" <<ENV
VITE_API_URL=$API_URL
ENV

pushd "$ROOT_DIR/frontend" >/dev/null
npm install
npm run build
npx --yes @azure/static-web-apps-cli deploy dist --deployment-token "$SWA_TOKEN" --env production
popd >/dev/null

printf '\nAplicación inicial desplegada.\n'
printf 'API: %s\n' "$API_URL"
printf 'Frontend: https://%s\n' "$(terraform -chdir="$ROOT_DIR/terraform" output -raw frontend_hostname)"
