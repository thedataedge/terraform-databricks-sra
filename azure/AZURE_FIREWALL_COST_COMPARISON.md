# Azure Firewall and Egress Cost Comparison

This document compares egress options relevant to the SRA hub deployment. The hub module supports **no firewall** (`is_firewall_enabled = false`), one of three Azure Firewall SKUs: **Basic**, **Standard**, and **Premium**, or (if implemented) **NAT Gateway** as a lower-cost alternative for stable egress IP without FQDN filtering.

> **Note:** Prices are in **USD** and based on [Azure Firewall pricing](https://azure.microsoft.com/en-us/pricing/details/azure-firewall/) and [Azure NAT Gateway pricing](https://azure.microsoft.com/en-us/pricing/details/azure-nat-gateway/) (pay-as-you-go). Actual costs depend on region, agreement type, and currency. Use the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) for your scenario.

---

## 1. Pricing components (Azure Firewall in VNet)

| Component | Basic | Standard | Premium |
|-----------|--------|----------|---------|
| **Deployment (per hour)** | $0.395 | $1.25 | $1.75 |
| **Data processed (per GB)** | $0.065 | $0.016 | $0.016 |
| **Capacity Unit (per hour)** | N/A | $0.07 | $0.11 |

- **Basic:** No capacity units; fixed deployment + data processing only. Throughput up to ~250 Mbps.
- **Standard / Premium:** Autoscaling; billing includes deployment + data processed + capacity unit hours. Standard scales up to ~30 Gbps; Premium up to ~100 Gbps with advanced threat protection.

### NAT Gateway (if implemented)

| Component | Rate |
|-----------|------|
| **Resource hours** | $0.045 per hour |
| **Data processed** | $0.045 per GB |

- **NAT Gateway:** Provides stable outbound public IP; no FQDN filtering or policy enforcement. Requires one Standard Public IP (~$4/mo) per NAT Gateway. Bandwidth charges also apply for data leaving Azure.
- **Security trade-off:** NAT enables connectivity only; firewall provides allow/deny rules, FQDN filtering, and inspection.

---

## 2. Scenario comparison: fixed monthly cost (deployment only)

Assumption: **730 hours/month** (24×7). No data or capacity units in this table.

| Scenario | Config | Deployment cost/month (USD) |
|----------|--------|-----------------------------|
| No firewall | `is_firewall_enabled = false` | $0 |
| NAT Gateway (if implemented) | Per spoke; 1 NAT + 1 PIP | ~\$37 |
| Firewall Basic | `is_firewall_enabled = true`, `firewall_sku = "Basic"` | ~\$288 |
| Firewall Standard | `is_firewall_enabled = true`, `firewall_sku = "Standard"` | ~\$913 |
| Firewall Premium | `is_firewall_enabled = true`, `firewall_sku = "Premium"` | ~\$1,278 |

---

## 3. Estimated monthly total by SKU and data volume

Formulas:

- **NAT Gateway:** `(0.045 × 730) + (0.045 × GB) + ~$4` (PIP) ≈ ~\$37 + \$0.045/GB  
- **Basic:** `(0.395 × 730) + (0.065 × GB)` = ~\$288 + \$0.065/GB  
- **Standard:** `(1.25 × 730) + (0.016 × GB) + (0.07 × CU_hours)`  
- **Premium:** `(1.75 × 730) + (0.016 × GB) + (0.11 × CU_hours)`  

Capacity units (CU) scale with throughput; for rough estimates, 2–6 CUs is typical for moderate traffic. Below we use **2 CUs** for Standard/Premium (2 × 730 = 1,460 CU-hours/month).

| Scenario | 100 GB/mo | 500 GB/mo | 1 TB/mo | 5 TB/mo | 10 TB/mo |
|----------|-----------|-----------|---------|---------|----------|
| **No firewall** | $0 | $0 | $0 | $0 | $0 |
| **NAT Gateway** (1 per spoke) | ~\$42 | ~\$60 | ~\$79 | ~\$263 | ~\$488 |
| **Basic** | ~\$295 | ~\$320 | ~\$354 | ~\$613 | ~\$938 |
| **Standard** (2 CUs) | ~\$1,016 | ~\$1,024 | ~\$1,040 | ~\$1,161 | ~\$1,282 |
| **Premium** (2 CUs) | ~\$1,394 | ~\$1,402 | ~\$1,418 | ~\$1,539 | ~\$1,660 |

*Standard/Premium data processing is much cheaper per GB ($0.016) than Basic ($0.065), so at higher data volumes Basic can exceed Standard on data charges.*

---

## 4. When each scenario is a better fit

| Scenario | Typical use |
|----------|-------------|
| **No firewall** | Dev/test, or egress secured by other means. Lowest cost, no central egress control. |
| **NAT Gateway** | Stable egress IP at ~\$37/mo base; no FQDN filtering. Use with NSGs and Databricks NCC for layered control. Suited for cost-sensitive deployments that can accept less restrictive outbound. |
| **Basic** | **Recommended default.** FQDN filtering, network rules, service tags at ~\$288/mo. Best balance of cost and security for most SRA deployments. Suited for egress &lt; ~250 Mbps. |
| **Standard** | Higher throughput, autoscaling. Use when Basic throughput limits are exceeded or scaling is required. |
| **Premium** | High security needs: IDPS, TLS inspection, advanced threat intelligence. Highest throughput and feature set. |

---

## 5. SRA configuration

In this repo, firewall is controlled in the hub module:

- **Enable/disable:** `is_firewall_enabled` (default: `true`) in the hub module.
- **SKU:** `firewall_sku` — `"Basic"` (default) \| `"Standard"` \| `"Premium"`.

Example (minimal) in root `main.tf` / `terraform.tfvars`:

```hcl
# Disable firewall (no Azure Firewall cost)
is_firewall_enabled = false

# Default: Basic SKU (~$288/mo, FQDN filtering)
# No need to set firewall_sku; Basic is the default.

# Or use Standard/Premium for higher throughput
firewall_sku = "Standard"   # or "Premium"
```

---

## 6. Quick reference (monthly, USD, ~730 h, 2 CUs for Std/Prem)

| Scenario | Low data (100 GB) | Medium (1 TB) | High (10 TB) |
|----------|-------------------|---------------|--------------|
| No firewall | $0 | $0 | $0 |
| NAT Gateway | ~\$42 | ~\$79 | ~\$488 |
| Basic | ~\$295 | ~\$354 | ~\$938 |
| Standard | ~\$1,016 | ~\$1,040 | ~\$1,282 |
| Premium | ~\$1,394 | ~\$1,418 | ~\$1,660 |

---

## 7. NAT Gateway implementation (future)

NAT Gateway is **not yet implemented** in this SRA. If added, it would:

- Be deployed per spoke (attached to `container` and `host` subnets)
- Require removing the hub firewall route (`0.0.0.0/0` → firewall) and firewall resources when used as the sole egress option
- Provide stable egress IP for allowlists; pair with NSGs, Databricks NCC, and private package repos for layered security

For your own data volumes and regions, use the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) (Firewall and NAT Gateway).
