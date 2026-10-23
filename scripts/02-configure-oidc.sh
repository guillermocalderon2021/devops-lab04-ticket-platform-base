#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/lab.env"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/bootstrap.env"

REPO="$GITHUB_REPOSITORY"
RG="$TFSTATE_RESOURCE_GROUP"

create_fic() {
  local identity=$1 name=$2 subject=$3
  az identity federated-credential create \
    --resource-group "$RG" \
    --identity-name "$identity" \
    --name "$name" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "$subject" \
    --audiences "api://AzureADTokenExchange" >/dev/null 2>&1 || true
}

create_fic "$PLAN_IDENTITY_NAME" "github-pr" "repo:${REPO}:pull_request"
for env in shared development production; do
  create_fic "$APPLY_IDENTITY_NAME" "github-${env}" "repo:${REPO}:environment:${env}"
done

printf 'Federated credentials configuradas para %s\n' "$REPO"
