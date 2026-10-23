#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/lab.env"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/bootstrap.env"

REPO="$GITHUB_REPOSITORY"
for env in shared development production; do
  gh api --method PUT "repos/${REPO}/environments/${env}" >/dev/null
done

declare -A VARS=(
  [AZURE_SUBSCRIPTION_ID]="$AZURE_SUBSCRIPTION_ID"
  [AZURE_TENANT_ID]="$AZURE_TENANT_ID"
  [AZURE_LOCATION]="$AZURE_LOCATION"
  [NAME_SUFFIX]="$NAME_SUFFIX"
  [PLAN_CLIENT_ID]="$PLAN_CLIENT_ID"
  [APPLY_CLIENT_ID]="$APPLY_CLIENT_ID"
  [TFSTATE_RESOURCE_GROUP]="$TFSTATE_RESOURCE_GROUP"
  [TFSTATE_STORAGE_ACCOUNT]="$TFSTATE_STORAGE_ACCOUNT"
  [TFSTATE_CONTAINER]="$TFSTATE_CONTAINER"
  [ACR_NAME]="$ACR_NAME"
  [IMAGE_NAME]="$IMAGE_NAME"
  [FRONTEND_IMAGE_NAME]="$FRONTEND_IMAGE_NAME"
)
for key in "${!VARS[@]}"; do
  gh variable set "$key" --repo "$REPO" --body "${VARS[$key]}"
done
printf 'GitHub Environments y variables configurados.\n'
