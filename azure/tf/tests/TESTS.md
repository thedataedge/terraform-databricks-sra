# Azure Terraform Tests Documentation

This document describes the Terraform tests for the Azure Databricks Secure Resource Architecture (SRA) module. Tests are located in `azure/tf/tests/` and use Terraform's native testing framework (`terraform test`).

---

## Table of Contents

1. [Test Suite Overview](#test-suite-overview)
2. [mock_plan.tftest.hcl — Unit Tests (Plan-Only)](#mock_plantftesthcl--unit-tests-plan-only)
3. [integration.tftest.hcl — Integration Tests (Apply)](#integrationtftesthcl--integration-tests-apply)
4. [Running the Tests](#running-the-tests)
5. [CI/CD Configuration](#cicd-configuration)
6. [Prerequisites](#prerequisites)

---

## Test Suite Overview

| File | Type | Command | Infrastructure | CI |
|------|------|---------|----------------|-----|
| `mock_plan.tftest.hcl` | Unit | `plan` | None (mocked providers) | Yes |
| `integration.tftest.hcl` | Integration | `apply` | Real Databricks workspace | No (manual) |

The Azure CI workflow (`.github/workflows/azure-test.yml`) runs **only** `mock_plan.tftest.hcl` because it uses mocked providers and requires no cloud credentials or existing infrastructure. Integration tests run against a live workspace and are executed manually.

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

## integration.tftest.hcl — Integration Tests (Apply)

These tests create and use real infrastructure. They require an already-applied Azure SRA environment with a Databricks workspace. Execution order is sequential due to dependencies between runs.

### Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sra_tag` | `"SRA Test Suite"` | Tag applied to test resources |
| `open_test_job` | `false` | If true, opens job pages in browser during runs |

### Run Blocks (Test Cases)

#### 1. `test_initializer`

- **Purpose:** Reads outputs from the local Terraform state in the cloud directory.
- **Module:** `../../common/tests/test_initializer`
- **Outputs:** `spoke_workspace_info`, `spoke_workspace_catalog` (used by downstream runs)
- **Command:** `apply`

#### 2. `classic_cluster_spoke`

- **Purpose:** Provisions a small autoscaling classic cluster for test jobs.
- **Module:** `../../common/tests/classic_cluster`
- **Dependencies:** `test_initializer` (for `databricks_host`)
- **Variables:** `databricks_host`, `tags`
- **Outputs:** `cluster_id`, `node_type_id`, `spark_version` (passed to bundle runs)
- **Validates:** Classic cluster creation

#### 3. `bundle_deploy`

- **Purpose:** Deploys the SRA bundle via `databricks bundle deploy --auto-approve`.
- **Module:** `../../common/tests/sra_bundle_test`
- **Dependencies:** `test_initializer`, `classic_cluster_spoke`
- **Validates:** Creating jobs, notebooks, experiments, models, lakebase
- **Outputs:** `working_dir` (used by `bundle_run` runs)

#### 4. `spark_basic`

- **Purpose:** Runs the basic Spark job from the bundle.
- **Module:** `../../common/tests/bundle_run`
- **Bundle job:** `spark_basic`
- **Validates:**
  - Running a Spark basic job
  - Creating a Unity Catalog schema
  - Creating a Unity Catalog table
  - Writing to and reading from a UC table

#### 5. `ml_workflow_classic`

- **Purpose:** Runs the ML workflow on a classic cluster.
- **Bundle job:** `ml_workflow_classic`
- **Validates:**
  - Creating UC tables
  - Writing/reading UC tables
  - Registering a model (blob endpoints for storage accounts)
  - Access to sample data (NYC taxi)

#### 6. `ml_cleanup_classic`

- **Purpose:** Cleans up resources created by `ml_workflow_classic`.
- **Bundle job:** `model_cleanup_classic`
- **Dependencies:** `ml_workflow_classic`
- **Validates:** Deleting a model from classic

#### 7. `ml_workflow_serverless`

- **Purpose:** Runs the ML workflow on serverless compute.
- **Bundle job:** `ml_workflow_serverless`
- **Validates:** Same as classic, but on serverless (UC tables, model registration, sample data)

#### 8. `ml_cleanup_serverless`

- **Purpose:** Cleans up resources created by `ml_workflow_serverless`.
- **Bundle job:** `model_cleanup_serverless`
- **Dependencies:** `ml_workflow_serverless`
- **Validates:** Deleting a model from serverless

#### 9. `lakebase_connectivity`

- **Purpose:** Tests Lakebase connectivity from classic.
- **Bundle job:** `lakebase`
- **Validates:** Connecting to Lakebase from a classic cluster

### Integration Test Flow

```
test_initializer → classic_cluster_spoke → bundle_deploy
                                               ↓
         spark_basic, ml_workflow_classic, ml_workflow_serverless, lakebase_connectivity
                                               ↓
         ml_cleanup_classic (after ml_workflow_classic)
         ml_cleanup_serverless (after ml_workflow_serverless)
```

---

## Running the Tests

### Unit Tests (mock_plan — CI Default)

```bash
cd azure/tf
terraform init -backend=false
terraform test -filter=tests/mock_plan.tftest.hcl
```

### Integration Tests (requires applied workspace)

```bash
cd azure/tf
terraform init
terraform apply   # Ensure workspace exists and state has outputs
terraform test -filter=tests/integration.tftest.hcl
```

### All Tests

```bash
cd azure/tf
terraform test
```

---

## CI/CD Configuration

The `.github/workflows/azure-test.yml` workflow:

- **Triggers:** Push/PR that touch `azure/tf/**` or the workflow file
- **Test filter:** `-filter=tests/mock_plan.tftest.hcl` — only unit tests
- **Backend:** `-backend=false` for plan-only tests
- **Additional:** Runs `terraform fmt` check and TFLint

Integration tests are **not** run in CI; they require a live Databricks workspace and credentials.

---

## Prerequisites

### Unit Tests (mock_plan)

- Terraform 1.6+
- No cloud credentials
- No existing infrastructure

### Integration Tests

- Terraform 1.6+
- Databricks CLI v0.218+ (for `databricks bundle` commands)
- Applied Azure SRA environment with state containing:
  - `spoke_workspace_info["prod"].workspace_url`
  - `spoke_workspace_catalog["prod"]`
- Authentication: `DATABRICKS_HOST`, `DATABRICKS_TOKEN` (or equivalent)

See `common/tests/README.md` for full prerequisites and troubleshooting.
