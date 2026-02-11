#!/usr/bin/env bash
# One-time bootstrap: create the storage account and/or container used for Terraform state
# in the resource group rg-tepe-terraform-mgmt.
#
# Usage:
#   ./scripts/bootstrap_backend.sh
# If the storage account already exists (e.g. stterraformstatetepe), only create the container:
#   SKIP_STORAGE_ACCOUNT=true ./scripts/bootstrap_backend.sh
#
# Optional env vars:
#   SUBSCRIPTION_ID        Azure subscription (default: current subscription)
#   STORAGE_ACCOUNT_NAME   Name for the storage account (default: stterraformstatetepe)
#   RESOURCE_GROUP         Resource group name (default: rg-tepe-terraform-mgmt)
#   LOCATION               Azure region (default: northeurope)
#   CONTAINER_NAME         Container name (default: tfstate)
#   SKIP_STORAGE_ACCOUNT   If true, only create the container in the existing storage account

set -e

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-tepe-terraform-mgmt}"
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-stterraformstatetepe}"
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"
LOCATION="${LOCATION:-northeurope}"
SKIP_STORAGE_ACCOUNT="${SKIP_STORAGE_ACCOUNT:-false}"

# Storage account names: 3-24 chars, lowercase letters and numbers only
if [[ ! "$STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "ERROR: STORAGE_ACCOUNT_NAME must be 3-24 lowercase letters/numbers (got: $STORAGE_ACCOUNT_NAME)"
  exit 1
fi

if [ -n "$SUBSCRIPTION_ID" ]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi

if [ "$SKIP_STORAGE_ACCOUNT" != "true" ]; then
  echo "Using resource group: $RESOURCE_GROUP"
  echo "Creating storage account: $STORAGE_ACCOUNT_NAME (location: $LOCATION)"
  az storage account create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false
else
  echo "SKIP_STORAGE_ACCOUNT=true: using existing storage account $STORAGE_ACCOUNT_NAME"
fi

echo "Creating container: $CONTAINER_NAME"
az storage container create \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --name "$CONTAINER_NAME" \
  --auth-mode login

echo "Done. Use this in backend.azurerm.hcl:"
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "  container_name       = \"$CONTAINER_NAME\""
echo "  key                  = \"azure.terraform.tfstate\""
echo ""
echo "Then: terraform init -backend-config=backend.azurerm.hcl"
