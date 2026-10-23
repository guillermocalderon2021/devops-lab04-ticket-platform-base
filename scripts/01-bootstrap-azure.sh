#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/lab.env"
GENERATED_FILE="$ROOT_DIR/config/bootstrap.env"

[[ -f "$CONFIG_FILE" ]] || { echo "Falta config/lab.env" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${AZURE_LOCATION:?Defina AZURE_LOCATION en config/lab.env}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ -f "$GENERATED_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$GENERATED_FILE"
  SUFFIX="$NAME_SUFFIX"
else
  SUFFIX=$(openssl rand -hex 3)
fi

RG="rg-ticket-bootstrap"
STORAGE="sttfstate${SUFFIX}"
CONTAINER="tfstate"
PLAN_ID="id-ticket-plan"
APPLY_ID="id-ticket-apply"
ACR_NAME="acrticket${SUFFIX}"

az group create --name "$RG" --location "$AZURE_LOCATION" >/dev/null
az storage account create \
  --name "$STORAGE" \
  --resource-group "$RG" \
  --location "$AZURE_LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false >/dev/null

ACCOUNT_ID=$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)
STORAGE_KEY=$(az storage account keys list --resource-group "$RG" --account-name "$STORAGE" --query "[0].value" -o tsv)
az storage container create --name "$CONTAINER" --account-name "$STORAGE" --account-key "$STORAGE_KEY" >/dev/null

az identity create -g "$RG" -n "$PLAN_ID" --location "$AZURE_LOCATION" >/dev/null
az identity create -g "$RG" -n "$APPLY_ID" --location "$AZURE_LOCATION" >/dev/null
PLAN_CLIENT_ID=$(az identity show -g "$RG" -n "$PLAN_ID" --query clientId -o tsv)
PLAN_PRINCIPAL_ID=$(az identity show -g "$RG" -n "$PLAN_ID" --query principalId -o tsv)
APPLY_CLIENT_ID=$(az identity show -g "$RG" -n "$APPLY_ID" --query clientId -o tsv)
APPLY_PRINCIPAL_ID=$(az identity show -g "$RG" -n "$APPLY_ID" --query principalId -o tsv)

SUB_SCOPE="/subscriptions/$SUBSCRIPTION_ID"
az role assignment create --assignee-object-id "$PLAN_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role Reader --scope "$SUB_SCOPE" >/dev/null || true
az role assignment create --assignee-object-id "$APPLY_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role Contributor --scope "$SUB_SCOPE" >/dev/null || true
az role assignment create --assignee-object-id "$PLAN_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$ACCOUNT_ID" >/dev/null || true
az role assignment create --assignee-object-id "$APPLY_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$ACCOUNT_ID" >/dev/null || true

cat > "$GENERATED_FILE" <<ENV
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_LOCATION=$AZURE_LOCATION
NAME_SUFFIX=$SUFFIX
TFSTATE_RESOURCE_GROUP=$RG
TFSTATE_STORAGE_ACCOUNT=$STORAGE
TFSTATE_CONTAINER=$CONTAINER
PLAN_CLIENT_ID=$PLAN_CLIENT_ID
PLAN_PRINCIPAL_ID=$PLAN_PRINCIPAL_ID
APPLY_CLIENT_ID=$APPLY_CLIENT_ID
APPLY_PRINCIPAL_ID=$APPLY_PRINCIPAL_ID
PLAN_IDENTITY_NAME=$PLAN_ID
APPLY_IDENTITY_NAME=$APPLY_ID
ACR_NAME=$ACR_NAME
ENV

printf 'Bootstrap creado. Valores guardados en config/bootstrap.env\n'
