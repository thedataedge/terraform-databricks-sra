# Azure Firewall Cost Comparison

This document compares Azure Firewall cost scenarios relevant to the SRA hub deployment. The hub module supports **no firewall** (`is_firewall_enabled = false`), or one of three SKUs: **Basic**, **Standard**, and **Premium**.

> **Note:** Prices are in **USD** and based on [Azure Firewall pricing](https://azure.microsoft.com/en-us/pricing/details/azure-firewall/) (pay-as-you-go). Actual costs depend on region, agreement type, and currency. Use the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/?service=azure-firewall) for your scenario.

---

## 1. Pricing components (Azure Firewall in VNet)

| Component | Basic | Standard | Premium |
|-----------|--------|----------|---------|
| **Deployment (per hour)** | $0.395 | $1.25 | $1.75 |
| **Data processed (per GB)** | $0.065 | $0.016 | $0.016 |
| **Capacity Unit (per hour)** | N/A | $0.07 | $0.11 |

- **Basic:** No capacity units; fixed deployment + data processing only. Throughput up to ~250 Mbps.
- **Standard / Premium:** Autoscaling; billing includes deployment + data processed + capacity unit hours. Standard scales up to ~30 Gbps; Premium up to ~100 Gbps with advanced threat protection.

---

## 2. Scenario comparison: fixed monthly cost (deployment only)

Assumption: **730 hours/month** (24×7). No data or capacity units in this table.

| Scenario | `is_firewall_enabled` | SKU | Deployment cost/month (USD) |
|----------|------------------------|-----|-----------------------------|
| No firewall | `false` | — | $0 |
| Firewall Basic | `true` | Basic | ~\$288 |
| Firewall Standard | `true` | Standard | ~\$913 |
| Firewall Premium | `true` | Premium | ~\$1,278 |

---

## 3. Estimated monthly total by SKU and data volume

Formulas:

- **Basic:** `(0.395 × 730) + (0.065 × GB)` = ~\$288 + \$0.065/GB  
- **Standard:** `(1.25 × 730) + (0.016 × GB) + (0.07 × CU_hours)`  
- **Premium:** `(1.75 × 730) + (0.016 × GB) + (0.11 × CU_hours)`  

Capacity units (CU) scale with throughput; for rough estimates, 2–6 CUs is typical for moderate traffic. Below we use **2 CUs** for Standard/Premium (2 × 730 = 1,460 CU-hours/month).

| Scenario | 100 GB/mo | 500 GB/mo | 1 TB/mo | 5 TB/mo | 10 TB/mo |
|----------|-----------|-----------|---------|---------|----------|
| **No firewall** | $0 | $0 | $0 | $0 | $0 |
| **Basic** | ~\$295 | ~\$320 | ~\$354 | ~\$613 | ~\$938 |
| **Standard** (2 CUs) | ~\$1,016 | ~\$1,024 | ~\$1,040 | ~\$1,161 | ~\$1,282 |
| **Premium** (2 CUs) | ~\$1,394 | ~\$1,402 | ~\$1,418 | ~\$1,539 | ~\$1,660 |

*Standard/Premium data processing is much cheaper per GB ($0.016) than Basic ($0.065), so at higher data volumes Basic can exceed Standard on data charges.*

---

## 4. When each scenario is a better fit

| Scenario | Typical use |
|----------|-------------|
| **No firewall** | Dev/test, or egress secured by other means (e.g. NAT only, no inspection). Lowest cost, no Azure Firewall. |
| **Basic** | Light egress (e.g. &lt; 250 Mbps), low data volume, cost-sensitive. No IDPS/advanced features. |
| **Standard** | Production: L3–L7 filtering, FQDN/App rules, autoscaling. Good balance of cost and capability for most SRA hub deployments. |
| **Premium** | High security needs: IDPS, TLS inspection, advanced threat intelligence. Highest throughput and feature set. |

---

## 5. SRA configuration

In this repo, firewall is controlled in the hub module:

- **Enable/disable:** `is_firewall_enabled` (default: `true`) in the hub module.
- **SKU:** `firewall_sku` — `"Basic"` \| `"Standard"` \| `"Premium"` (default: `"Standard"`).

Example (minimal) in root `main.tf` / `terraform.tfvars`:

```hcl
# Disable firewall (no Azure Firewall cost)
is_firewall_enabled = false

# Or use a specific SKU (e.g. cost-optimized)
is_firewall_enabled = true
firewall_sku       = "Basic"   # or "Standard" (default) or "Premium"
```

---

## 6. Quick reference (monthly, USD, ~730 h, 2 CUs for Std/Prem)

| Scenario | Low data (100 GB) | Medium (1 TB) | High (10 TB) |
|----------|-------------------|---------------|--------------|
| No firewall | $0 | $0 | $0 |
| Basic | ~\$295 | ~\$354 | ~\$938 |
| Standard | ~\$1,016 | ~\$1,040 | ~\$1,282 |
| Premium | ~\$1,394 | ~\$1,418 | ~\$1,660 |

For your own data volumes and regions, use the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/?service=azure-firewall).
