# Azure Terraform Tests Documentation

This document describes the Terraform tests for the Azure Databricks Secure Resource Architecture (SRA) module. Tests are located in `azure/tf/tests/` and use Terraform's native testing framework (`terraform test`).

---

## Table of Contents

1. [Test Suite Overview](#test-suite-overview)
2. [mock_plan.tftest.hcl — Unit Tests (Plan-Only)](#mock_plantftesthcl--unit-tests-plan-only)
3. [Running the Tests](#running-the-tests)
4. [CI/CD Configuration](#cicd-configuration)
5. [Prerequisites](#prerequisites)

---

## Test Suite Overview

| File | Type | Command | Infrastructure | CI |
|------|------|---------|----------------|-----|
| `mock_plan.tftest.hcl` | Unit | `plan` | None (mocked providers) | Yes |

The Azure CI workflow (`.github/workflows/azure-test.yml`) runs `mock_plan.tftest.hcl`, which uses mocked providers and requires no cloud credentials or existing infrastructure.

---

## mock_plan.tftest.hcl — Unit Tests (Plan-Only)

These tests validate Terraform configuration logic without creating any infrastructure. They use **mock providers** to stub Azure and Databricks API responses, allowing `terraform plan` to complete successfully.

### Mock Providers

The following providers are mocked:

| Provider | Mock Data | Purpose |
|----------|-----------|---------|
| `azurerm` | `azurerm_client_config`, `azurerm_subscription` | Tenant ID, object ID, subscription ID |
| `azuread` | `azuread_application_published_app_ids`, `azuread_service_principal` | Azure Data Bricks app ID, service principal object ID |
| `databricks` | `databricks_user` | Default user ID (0) |
| `databricks` (alias: SAT) | — | Secure Agent for Terraform (SAT) provider alias |

All mock values use placeholder GUIDs (e.g. `00000000-0000-0000-0000-000000000000`) to satisfy ID validation.

### Run Blocks (Test Cases)

#### 1. `plan_test_defaults`

- **Purpose:** Validates the root module with default variable values.
- **Variables:** None (uses terraform.tfvars or variable defaults).
- **Expectation:** Plan succeeds with default configuration.

#### 2. `plan_test_sat_broken_classic`

- **Purpose:** Ensures SAT (Secure Agent for Terraform) validation fails when classic clusters are configured without allowed FQDNs.
- **Variables:**
  - `sat_configuration.enabled = true`
  - `allowed_fqdns = []`
  - `hub_allowed_urls = []`
- **Expectation:** Plan fails with `expect_failures = [var.allowed_fqdns]` — i.e. validation catches missing allowed FQDNs for classic.

#### 3. `plan_test_sat_broken_serverless`

- **Purpose:** Ensures SAT validation fails when serverless is configured without hub-allowed URLs.
- **Variables:**
  - `sat_configuration.enabled = true`
  - `sat_configuration.run_on_serverless = true`
  - `allowed_fqdns = []`
  - `hub_allowed_urls = []`
- **Expectation:** Plan fails with `expect_failures = [var.hub_allowed_urls]` — validation catches missing hub URLs for serverless.

#### 4. `plan_test_sat_with_byosp`

- **Purpose:** Validates SAT with bring-your-own service principal (BYOSP).
- **Variables:**
  - `allowed_fqdns`: Management, login, Python package domains (management.azure.com, login.microsoftonline.com, python.org, pypi.org, etc.)
  - `sat_configuration.enabled = true`
  - `sat_service_principal`: Empty client_id/client_secret (placeholder for BYOSP).
- **Expectation:** Plan succeeds with SAT enabled and BYOSP structure.

#### 5. `plan_test_sat_nondefaults`

- **Purpose:** Validates SAT with non-default schema, catalog, proxy, and serverless setting.
- **Variables:**
  - `allowed_fqdns`: Same as above
  - `sat_configuration.enabled = true`
  - `sat_configuration.proxies = { "http_proxy" : "http://localhost:80" }`
  - `sat_configuration.run_on_serverless = false`
  - `sat_configuration.schema_name = "notsat"`
  - `sat_configuration.catalog_name = "notsat"`
- **Expectation:** Plan succeeds with custom SAT configuration.

#### 6. `plan_test_byo_hub_with_spoke`

- **Purpose:** Validates bring-your-own (BYO) hub with spoke workspaces — hub VNet and NCC provided externally.
- **Variables:**
  - `create_hub = false`
  - `databricks_metastore_id`: Mock GUID
  - `spokes`: prod and dev with custom resource suffixes and VNet CIDR
  - `existing_ncc_id`, `existing_ncc_name`, `existing_network_policy_id`
  - `existing_cmk_ids`: Key Vault and key IDs for CMK
  - `existing_hub_vnet`: Route table and VNet IDs for external hub
- **Expectation:** Plan succeeds with external hub and NCC integration.

#### 7. `plan_test_cmk_disabled`

- **Purpose:** Validates configuration with customer-managed keys (CMK) disabled.
- **Variables:**
  - `cmk_enabled = false`
  - `spokes`: prod (`nocmk`) and dev (`nocmk-dev`) with workspace VNets
- **Expectation:** Plan succeeds without CMK resources.

#### 8. `plan_test_enhanced_security`

- **Purpose:** Validates enhanced security and compliance profile.
- **Variables:**
  - `spokes`: prod (`secure`) and dev (`secure-dev`)
  - `workspace_security_compliance`:
    - `automatic_cluster_update_enabled = true`
    - `compliance_security_profile_enabled = true`
    - `compliance_security_profile_standards = ["HIPAA", "PCI_DSS"]`
    - `enhanced_security_monitoring_enabled = true`
- **Expectation:** Plan succeeds with security compliance settings.

#### 9. `plan_test_byo_resource_group`

- **Purpose:** Validates bring-your-own resource group for workspace.
- **Variables:**
  - `spokes`: prod and dev with `create_workspace_resource_group = false`
  - Resource suffixes: `byorg`, `byorg-dev`
- **Expectation:** Plan succeeds with external resource groups.

#### 10. `plan_test_name_overrides`

- **Purpose:** Validates custom workspace and private endpoint names.
- **Variables:**
  - `spokes`: prod (`custom`) and dev (`custom-dev`)
  - `workspace_name_overrides`:
    - `databricks_workspace = "my-custom-workspace"`
    - `private_endpoint = "pe-custom-databricks"`
- **Expectation:** Plan succeeds with custom naming.

#### 11. `plan_test_custom_subnet_sizing`

- **Purpose:** Validates custom subnet sizing via `new_bits`.
- **Variables:**
  - `spokes`: prod (`customsubs`) and dev (`customsubs-dev`)
  - `workspace_vnet.new_bits = 3` (splits CIDR into subnets)
- **Expectation:** Plan succeeds with custom subnet layout.

### Removed Test: `plan_test_byo_hub_byo_network`

The `plan_test_byo_hub_byo_network` run was removed because `create_workspace_vnet = false` with `existing_workspace_vnet` is not supported in the current multi-spoke design. The `spoke.tf` module always references `module.spoke_network`, which is empty when workspace VNet creation is disabled.

---

## Running the Tests

```bash
cd azure/tf
terraform init -backend=false
terraform test -filter=tests/mock_plan.tftest.hcl
```

---

## CI/CD Configuration

The `.github/workflows/azure-test.yml` workflow:

- **Triggers:** Push/PR that touch `azure/tf/**` or the workflow file
- **Test filter:** `-filter=tests/mock_plan.tftest.hcl`
- **Backend:** `-backend=false` for plan-only tests
- **Additional:** Runs `terraform fmt` check and TFLint

---

## Prerequisites

- Terraform 1.6+
- No cloud credentials required
- No existing infrastructure
