# Databricks SRA — Terraform Implementation Overview

*Short presentation script for clients. Reference this when walking through the codebase.*

---

## 1. What We're Building (30 seconds)

A **hub-and-spoke** architecture on Azure for Databricks:

- **Hub** — Shared network, firewall, Unity Catalog metastore, and encryption keys
- **Spokes** — Prod and dev workspaces, each with its own VNet, workspace, and Unity Catalog catalog
- **Security** — VNet injection, Private Link, Azure Firewall (Basic), CMK, NCC

---

## 2. Entry Point

**`azure/tf/main.tf`**

- Orchestrates the hub (`module.hub`) when `create_hub = true`
- Passes firewall, CMK, and network settings into the hub
- Uses `var.spokes` to drive prod/dev creation

*"Everything starts here. Main.tf wires the hub and hands off to spoke.tf."*

---

## 3. Hub (Shared Infrastructure)

**`azure/tf/modules/hub/main.tf`** — Hub VNet, subnets, and network wiring  
**`azure/tf/modules/hub/firewall.tf`** — Azure Firewall (Basic), IP group, route table, firewall rules  
**`azure/tf/modules/hub/unitycatalog.tf`** — Metastore and NCC (Network Connectivity Config)  
**`azure/tf/modules/hub/keyvault.tf`** — Key Vault and CMK for workspace encryption  

*"The hub is a reusable module. Firewall filters outbound traffic; Unity Catalog and CMK are shared across spokes."*

---

## 4. Spokes (Per-Environment)

**`azure/tf/spoke.tf`**

- One resource group per spoke (`prod`, `dev`)
- **`module.spoke_network`** → `modules/virtual_network` — VNet, container/host subnets, privatelink
- **`module.spoke_workspace`** → `modules/workspace` — Databricks workspace (Premium, SCC, CMK)
- **`module.spoke_catalog_prod` / `spoke_catalog_dev`** → `modules/catalog` — Unity Catalog catalog per spoke

*"Each spoke gets its own network, workspace, and catalog. They share the hub’s metastore, NCC, and firewall."*

---

## 5. Key Modules (Quick Reference)

| Module | Path | Purpose |
|--------|------|---------|
| Virtual Network | `modules/virtual_network/` | VNet, subnets (container, host, privatelink), NSG, Private DNS |
| Workspace | `modules/workspace/` | Databricks workspace, backend/webauth private endpoints, DBFS |
| Catalog | `modules/catalog/` | Unity Catalog catalog, external location, storage account |

---

## 6. Configuration

**`azure/tf/variables.tf`** — All inputs (`spokes`, `firewall_sku`, `hub_vnet_cidr`, etc.)  
**`azure/tf/terraform.tfvars`** — Example values; copy and adapt for your environment  

*"Change `spokes`, `is_firewall_enabled`, and `firewall_sku` in variables/tfvars to tune the deployment."*

---

## 7. Deployment Flow (One Sentence)

> **Init** (`terraform init -backend-config=...`) → **Plan** (`terraform plan`) → **Apply** (`terraform apply`). Hub provisions first, then spokes; each spoke gets a workspace and catalog linked to the shared metastore.

---

## 8. Where to Look for X

| Topic | File(s) |
|-------|---------|
| Hub network & firewall | `modules/hub/main.tf`, `modules/hub/firewall.tf` |
| Spoke VNets & configurables | `spoke.tf`, `modules/virtual_network/` |
| Databricks workspace setup | `modules/workspace/main.tf`, `modules/workspace/backend_privatelink.tf` |
| Unity Catalog | `modules/hub/unitycatalog.tf`, `modules/catalog/` |
| Firewall rules | `modules/hub/firewall.tf` (network + application rules) |
