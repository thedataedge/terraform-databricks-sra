# Azure Databricks Secure Reference Architecture (SRA) — Terraform

<p align="center">
  <img src="https://i.postimg.cc/hP90xPqh/SRA-Screenshot.png" alt="SRA Architecture" width="600" />
</p>

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Terraform State Backend](#terraform-state-backend)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Support & License](#support--license)

---

## Project Overview

The **Azure Databricks Secure Reference Architecture** (SRA) is a production-ready Terraform template that deploys Databricks workspaces on Azure with security best practices. Built on the [Databricks Security Best Practices](https://www.databricks.com/trust/security-features#best-practices), it provides a strong, prescriptive foundation for secure deployments with hub-spoke networking, Azure Firewall, Unity Catalog, and Private Endpoints.

| Capability | Description |
|------------|-------------|
| **Hub-Spoke Topology** | Central hub VNet with peered spoke VNets for workspace isolation |
| **Azure Firewall** | Optional FQDN filtering and network rules (Basic/Standard/Premium) |
| **Private Endpoints** | Backend Private Link for Databricks control plane; optional web auth |
| **Unity Catalog** | Unified data governance with per-spoke catalogs |
| **Multi-Spoke** | Prod and dev spokes with separate resource groups, VNets, and workspaces |
| **Customer-Managed Keys** | Optional CMK for workspace encryption |

---

## Architecture

The architecture follows a hub-spoke model:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HUB VNET                                        │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────────────────────┐ │
│  │ Azure        │  │ Azure Firewall │  │ NCC / Metastore / Key Vault     │ │
│  │ Firewall     │  │ (Basic default)│  │ (Shared account-level resources) │ │
│  │ Subnet       │  └────────────────┘ └─────────────────────────────────┘ │
│  └──────────────┘                                                           │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │ VNet Peering
         ┌───────────────────────────┴───────────────────────────┐
         │                                                       │
┌────────▼─────────┐                                   ┌─────────▼──────────┐
│   SPOKE (prod)   │                                   │   SPOKE (dev)      │
│  ┌────────────┐  │                                   │  ┌────────────┐     │
│  │ Databricks │  │                                   │  │ Databricks │     │
│  │ Workspace  │  │                                   │  │ Workspace  │     │
│  │ + Catalog  │  │                                   │  │ + Catalog  │     │
│  │ + ADF      │  │                                   │  │ + ADF      │     │
│  └────────────┘  │                                   │  └────────────┘     │
└──────────────────┘                                   └────────────────────┘
```

### Network Flow

- **Hub:** Contains Azure Firewall (optional), route table, and IP group for workspace outbound control. Container and host subnets are **not** in the hub—they live only in spokes.
- **Spokes:** Each spoke has its own resource group, VNet, Databricks workspace, Unity Catalog catalog, and Azure Data Factory instance. Workspace compute subnets (container, host) and privatelink subnet reside in the spoke VNet.
- **Outbound:** When firewall is enabled, workspace traffic routes through the hub firewall via VirtualAppliance. When disabled, traffic uses default Azure routing.

### Frontend/Backend Access

| Component | Default | Description |
|-----------|---------|-------------|
| Frontend Private Link | Disabled | Users access Databricks UI via public network |
| Backend Private Endpoint | Enabled (`databricks_ui_api`) | Control plane API uses Private Link |
| Webauth Private Endpoint | Disabled | Optional for browser authentication |
| Public network access | Enabled | Required for UI access when frontend PE is disabled |

---

## Key Features

### Hub Module

| Component | Purpose |
|-----------|---------|
| `main.tf` | Orchestrates hub VNet; passes route_table_id and ipgroup_id to virtual_network |
| `firewall.tf` | Azure Firewall (optional), policy, public IP, IP group, route table |
| `virtual_network/*` | Hub VNet, subnets (AzureFirewallSubnet, AzureFirewallManagementSubnet for Basic), NSG |

### Azure Firewall

- **SKUs:** Basic (default, ~$288/mo), Standard (~$913/mo), Premium (~$1,278/mo)
- **Basic SKU:** Best cost/security balance for medium traffic; includes FQDN filtering, network rules, and AzureFirewallManagementSubnet
- **Disable:** Set `is_firewall_enabled = false` to omit firewall (no central egress control; traffic uses default routing)
- **Cost details:** See [azure/docs/AZURE_FIREWALL_COST_COMPARISON.md](azure/docs/AZURE_FIREWALL_COST_COMPARISON.md)

### Two-Spoke Design (Prod & Dev)

The `spokes` variable defines prod and dev environments. Each spoke receives:

- Resource group: `rg-<resource_suffix>`
- Workspace VNet with container, host, and privatelink subnets
- Databricks workspace (Premium SKU, SCC, CMK, NCC)
- Unity Catalog catalog (named from `resource_suffix`)
- Azure Data Factory instance: `adf-<resource_suffix>`
- Legacy settings (disable legacy DBFS and access)

### Security Analysis Tool (SAT)

SAT is disabled by default. When enabled, it runs in the hub workspace (WEBAUTH) and can be customized via `sat_configuration` and `sat_service_principal`. See [azure/README.md](azure/README.md) for SAT configuration and BYO service principal.

---

## Project Structure

```
terraform-databricks-sra/
├── README.md                    # This file
├── LICENSE
├── azure/
│   ├── README.md                # Detailed Azure SRA documentation
│   ├── docs/
│   │   ├── AZURE_FIREWALL_COST_COMPARISON.md
│   │   └── SHIR_SETUP_GUIDE.md
│   └── tf/                      # Terraform root module
│       ├── main.tf              # Hub module, locals
│       ├── spoke.tf             # Spoke networks, workspaces, catalogs
│       ├── data_factory.tf      # Azure Data Factory per spoke
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── versions.tf
│       ├── datasources.tf
│       ├── customizations.tf     # SAT (optional, largely commented)
│       ├── backend.azurerm.example.hcl
│       ├── tests/
│       │   ├── mock_plan.tftest.hcl
│       │   ├── integration.tftest.hcl
│       │   ├── terraform.tfvars
│       │   └── TESTS.md
│       └── modules/
│           ├── hub/             # Hub VNet, firewall, NCC, metastore
│           ├── virtual_network/# VNet, subnets, DNS, peering
│           ├── workspace/      # Databricks workspace
│           ├── catalog/        # Unity Catalog catalog + storage
│           ├── sat/            # Security Analysis Tool (optional)
│           └── self-approving-pe/
└── .github/
    └── workflows/
        ├── azure-test.yml      # CI for Azure Terraform
        ├── terraform-ruw.yml   # Reusable: TFLint, fmt, test
        └── README.md
```

### Outputs

| Output | Description |
|--------|-------------|
| `spoke_workspace_info` | Per spoke: resource_group_name, workspace_url, workspace_id |
| `spoke_workspace_catalog` | Per spoke: catalog name |
| `spoke_data_factory_info` | Per spoke: Data Factory id and name |
| `hub_network_subnets` | Hub network CIDR blocks |
| `hub_resource_group_name` | Hub resource group name |

---

## Terraform State Backend

State is stored in Azure Blob Storage. Default configuration uses:

- **Resource group:** `rg-tepe-terraform-mgmt`
- **Storage account:** `stterraformstatetepe` (northeurope)
- **Container:** `tfstate`
- **Key:** `azure.terraform.tfstate`

### Setup

1. **Create the tfstate container** (if storage account already exists):

   ```bash
   cd azure/tf
   SKIP_STORAGE_ACCOUNT=true ./scripts/bootstrap_backend.sh
   ```

   If both RG and storage account are new, run without `SKIP_STORAGE_ACCOUNT`.

2. **Configure backend:**

   ```bash
   cp backend.azurerm.example.hcl backend.azurerm.hcl
   # Edit if using different storage account
   ```

3. **Initialize with backend:**

   ```bash
   terraform init -backend-config=backend.azurerm.hcl
   ```

> `backend.azurerm.hcl` is gitignored. Keep it out of version control.

### State Lock

If `terraform plan` fails with "state blob is already locked":

```bash
terraform force-unlock <LOCK_ID>
```

Use the Lock ID from the error message. Confirm with `yes` when prompted.

---

## Testing

### Unit Tests (Mock Plan)

No cloud credentials required. Uses mocked providers.

```bash
cd azure/tf
terraform init -backend=false
terraform test -filter=tests/mock_plan.tftest.hcl
```

### CI

The `.github/workflows/azure-test.yml` workflow runs on push/PR to `azure/tf/**`:

- TFLint
- `terraform fmt -check`
- `terraform test -filter=tests/mock_plan.tftest.hcl`

See [azure/tf/tests/TESTS.md](azure/tf/tests/TESTS.md) for full test documentation.

---

## Troubleshooting

### "Required plugins are not installed"

Run `terraform init` before `terraform plan` or `terraform apply`.

### State lock error

```
Error acquiring the state lock
state blob is already locked
```

Run `terraform force-unlock <LOCK_ID>` using the Lock ID from the error. Only when you are certain no other Terraform process is running.

### Azure CLI / Tenant ID mismatch

```
Expected iss claim to be: https://sts.windows.net/.../ but was: https://sts.windows.net/.../
```

Set the correct tenant ID:

```bash
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
```

### Unauthorized access to Org

```
Error: cannot read current user: Unauthorized access to Org
```

Log in to the newly created workspace in the Azure portal as the user running Terraform (click "Launch Workspace"). The first user to launch becomes workspace admin.

### Azure Firewall Basic requires Management Subnet

If you see "Invalid index" for `AzureFirewallManagementSubnet`, ensure you are using a version that adds `AzureFirewallManagementSubnet` when `firewall_sku == "Basic"`. The hub module should pass `extra_subnets` to include this subnet.

---

## Additional Resources

| Resource | Location |
|----------|----------|
| Azure SRA details | [azure/README.md](azure/README.md) |
| Firewall cost comparison | [azure/docs/AZURE_FIREWALL_COST_COMPARISON.md](azure/docs/AZURE_FIREWALL_COST_COMPARISON.md) |
| SHIR setup (ADF) | [azure/docs/SHIR_SETUP_GUIDE.md](azure/docs/SHIR_SETUP_GUIDE.md) |
| Databricks Terraform docs | [registry.terraform.io/providers/databricks/databricks](https://registry.terraform.io/providers/databricks/databricks/latest/docs) |
| Architecture diagram | [Databricks blog](https://cms.databricks.com/sites/default/files/inline-images/db-9734-blog-img-4.png) |
