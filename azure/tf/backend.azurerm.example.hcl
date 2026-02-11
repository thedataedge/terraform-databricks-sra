# Terraform Azure backend configuration (partial).
# Copy to backend.azurerm.hcl and run: terraform init -backend-config=backend.azurerm.hcl
#
# Uses existing rg-tepe-terraform-mgmt and storage account stterraformstatetepe.
# If the tfstate container does not exist yet, create it with:
#   SKIP_STORAGE_ACCOUNT=true ./scripts/bootstrap_backend.sh

resource_group_name  = "rg-tepe-terraform-mgmt"
storage_account_name = "stterraformstatetepe"
container_name       = "tfstate"
key                  = "azure.terraform.tfstate"
