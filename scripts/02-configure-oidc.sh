#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1090
source "$ROOT_DIR/config/lab.env"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/bootstrap.env"

REPO="$GITHUB_REPOSITORY"
RG="$TFSTATE_RESOURCE_GROUP"

if [[ ! "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
  printf 'GITHUB_REPOSITORY debe tener el formato OWNER/REPOSITORY. Valor recibido: %s\n' "$REPO" >&2
  exit 1
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO#*/}"

OWNER_ID="$(gh api "users/${OWNER}" --jq '.id')"
REPO_ID="$(gh api "repos/${REPO}" --jq '.id')"

if [[ -z "$OWNER_ID" || -z "$REPO_ID" ]]; then
  printf 'No fue posible obtener los identificadores inmutables de GitHub para %s\n' "$REPO" >&2
  exit 1
fi

REPO_SUBJECT_PREFIX="repo:${OWNER}@${OWNER_ID}/${REPO_NAME}@${REPO_ID}"

create_fic() {
  local identity=$1
  local name=$2
  local subject=$3

  if az identity federated-credential show       --resource-group "$RG"       --identity-name "$identity"       --name "$name" >/dev/null 2>&1; then
    az identity federated-credential delete       --resource-group "$RG"       --identity-name "$identity"       --name "$name"       --yes >/dev/null
  fi

  az identity federated-credential create     --resource-group "$RG"     --identity-name "$identity"     --name "$name"     --issuer "https://token.actions.githubusercontent.com"     --subject "$subject"     --audiences "api://AzureADTokenExchange" >/dev/null
}

create_fic   "$PLAN_IDENTITY_NAME"   "github-pr"   "${REPO_SUBJECT_PREFIX}:pull_request"

for env in shared development production; do
  create_fic     "$APPLY_IDENTITY_NAME"     "github-${env}"     "${REPO_SUBJECT_PREFIX}:environment:${env}"
done

printf 'Federated credentials configuradas para %s\n' "$REPO"
printf 'Formato OIDC usado: %s\n' "$REPO_SUBJECT_PREFIX"
