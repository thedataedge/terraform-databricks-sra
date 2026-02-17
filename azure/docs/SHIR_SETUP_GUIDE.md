# Self-Hosted Integration Runtime (SHIR) Setup Guide

Step-by-step guide to create a Self-Hosted Integration Runtime in the integration VNet (`vnet-int-prod-swc`) and connect it to Azure Data Factory instances for on-premises-to-storage copy activities.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  vnet-int-prod-swc (integration VNet - existing)                             │
│  Location: Sweden Central | RG: rg-int-prod-swc-common                      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  snet-integration-prod-swc (10.60.115.32/27)                        │    │
│  │  ┌────────────────────────────────────────────────────────────────┐ │    │
│  │  │  SHIR VM (Windows Server)                                       │ │    │
│  │  │  - Runs Microsoft Integration Runtime service                   │ │    │
│  │  │  - Executes copy activities                                     │ │    │
│  │  └────────────────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Private Endpoint for Storage (new subnet or use existing)          │    │
│  │  - blob + dfs subresources for spoke storage account                │    │
│  │  - Private DNS zones linked for name resolution                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  GatewaySubnet ─────────────────────► VPN/ExpressRoute ──► On-prem SQL       │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Private Link
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Spoke storage account (private)                                             │
│  - Unity Catalog storage / landing zone                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- [ ] Azure subscription with Owner or Contributor access
- [ ] Existing VNet `vnet-int-prod-swc` with `GatewaySubnet` (on-prem connectivity)
- [ ] ADF instances deployed (e.g. `adf-tepe-prod`, `adf-tepe-dev`)
- [ ] Target storage account(s) in spoke(s), private (`public_network_access_enabled = false`)
- [ ] Windows Server 2016/2019/2022 or Windows 10/11 VM image
- [ ] Optional: [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) or [PowerShell Az](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps) for automation

---

## Part 1: Prepare the integration VNet

### Step 1.1: Choose a subnet for the SHIR VM

Use an existing subnet with connectivity to the gateway (for on-prem) and room for a private endpoint.

| Subnet                     | CIDR             | Suited for SHIR |
|----------------------------|------------------|-----------------|
| snet-integration-prod-swc  | 10.60.115.32/27  | ✅ Recommended   |
| snet-db01-prod-swc         | 10.60.115.128/27 | ⚠️ Delegated to App Service – avoid |
| snet-api-prod-swc          | 10.60.115.0/27   | ⚠️ Typically for APIs – use if approved |

**Recommendation:** Use `snet-integration-prod-swc`.

### Step 1.2: (Optional) Create a dedicated SHIR subnet

If you want a dedicated subnet (easier to manage and lock down):

1. Azure Portal → **Virtual networks** → `vnet-int-prod-swc`
2. **Subnets** → **+ Subnet**
3. Configure:
   - **Name:** `snet-shir-prod-swc`
   - **Subnet address range:** e.g. `10.60.115.160/28` (confirm no overlap with existing subnets)
   - **NAT gateway:** None
   - **Network security group:** Create or select one
   - **Private endpoint network policies:** Disabled
   - **Private link service network policies:** Disabled

---

## Part 2: Create the Windows VM

### Step 2.1: Create the VM in the portal

1. Azure Portal → **Create a resource** → **Virtual machine**
2. **Basics:**
   - **Subscription:** your subscription
   - **Resource group:** `rg-int-prod-swc-common` (or same RG as the integration VNet)
   - **Virtual machine name:** `vm-shir-prod-swc`
   - **Region:** Sweden Central (same as VNet)
   - **Image:** Windows Server 2022 Datacenter – Azure Gen2
   - **Size:** B2s (2 vCPU, 4 GiB) or B2s v2 (2 vCPU, 8 GiB)
   - **Username:** local admin (e.g. `azadmin`)
   - **Password:** strong password
   - **Licensing:** Use existing Windows license if eligible, else Pay-as-you-go

3. **Disks:** default

4. **Networking:**
   - **Virtual network:** `vnet-int-prod-swc`
   - **Subnet:** `snet-integration-prod-swc` (or `snet-shir-prod-swc`)
   - **Public IP:** **None** (private only)
   - **NIC network security group:** create one (e.g. `nsg-shir-prod-swc`)

5. **Management:**
   - Boot diagnostics: Optional
   - Enable auto-shutdown: Optional (not for prod)

6. **Review + create** → **Create**

### Step 2.2: NSG outbound rules

SHIR needs outbound access to:

- Azure Relay: `*.servicebus.windows.net` (port 443)
- Data Factory control plane: `*.datafactory.azure.net` (port 443)
- Optional: `download.microsoft.com` (port 443) for SHIR updates

1. VM → **Networking** → **Network settings** → **Outbound port rules**
2. Add rules to allow outbound 443 to:
   - Service tag `AzureCloud` (or specific FQDNs above)
   - Or create an application rule for `*.servicebus.windows.net` and `*.datafactory.azure.net` if using Azure Firewall

### Step 2.3: RDP access (temporary)

To install and configure SHIR:

1. VM → **Connect** → **RDP**
2. Download RDP file
3. If no public IP: use **Bastion** or a VPN/jump host that can reach the VNet
4. Connect and log in with the admin account

---

## Part 3: Create Private Endpoint(s) for Storage

Your spoke storage is private. SHIR in the integration VNet needs a private endpoint to reach it.

### Step 3.1: Get storage account details

1. Azure Portal → **Storage accounts**
2. Find the spoke storage (e.g. `st<unique>uc` or similar)
3. Note: **Subscription**, **Resource group**, **Name**

### Step 3.2: Create Private DNS zones (if not present)

Private DNS zones for storage are typically in the spoke. You need equivalent zones linked to the integration VNet, or create them if missing.

1. Portal → **Private DNS zones** → **+ Create**
2. Create two zones:

| Zone name | Purpose |
|-----------|---------|
| `privatelink.blob.core.windows.net` | Blob storage |
| `privatelink.dfs.core.windows.net`  | DFS (Data Lake) |

3. **Review + create**

### Step 3.3: Link zones to the integration VNet

1. For each zone → **Virtual network links** → **+ Add**
2. Add link:
   - **Link name:** e.g. `link-vnet-int-prod-swc`
   - **Virtual network:** `vnet-int-prod-swc`
   - **Enable auto registration:** No
3. Save

### Step 3.4: Create Private Endpoint for Blob

1. Storage account → **Networking** → **Private endpoint connections** → **+ Private endpoint**
2. **Basics:**
   - **Subscription / Resource group:** same as VNet
   - **Name:** `pe-storage-blob-shir`
   - **Region:** Sweden Central
3. **Resource:**
   - **Target sub-resource:** Blob
   - **Resource:** storage account (pre-selected)
4. **Virtual Network:**
   - **Virtual network:** `vnet-int-prod-swc`
   - **Subnet:** `snet-integration-prod-swc`
   - **Integrate with private DNS zone:** Yes
   - **Subscription:** yours
   - **Private DNS zone:** `privatelink.blob.core.windows.net`
5. **Tags:** optional
6. **Review + create** → **Create**

### Step 3.5: Create Private Endpoint for DFS

Repeat Step 3.4 with:

- **Name:** `pe-storage-dfs-shir`
- **Target sub-resource:** `dfs`
- **Private DNS zone:** `privatelink.dfs.core.windows.net`

### Step 3.6: Approve the connections

1. Storage account → **Networking** → **Private endpoint connections**
2. Both connections should appear as **Approved** (auto-approved in same tenant)
3. If **Pending**, select each → **Approve**

### Step 3.7: Verify connectivity from the SHIR VM

1. RDP to the SHIR VM
2. Run PowerShell:

```powershell
# Replace with your storage account name
$storageAccount = "yourstorageaccountname"
Test-NetConnection -ComputerName "$storageAccount.blob.core.windows.net" -Port 443
Test-NetConnection -ComputerName "$storageAccount.dfs.core.windows.net" -Port 443
```

Both should succeed with a resolved private IP and `TcpTestSucceeded : True`.

---

## Part 4: Install the Self-Hosted Integration Runtime

### Step 4.1: Download SHIR installer

1. Open browser on the SHIR VM
2. Go to [Microsoft Integration Runtime Download](https://www.microsoft.com/download/details.aspx?id=39717)
3. Download **64-bit version**
4. Or download directly: https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-2A7D086A93AE/IntegrationRuntime_5.34.9634.1.msi

### Step 4.2: Install SHIR

1. Run the MSI
2. Accept terms → **Install** → **Finish**
3. Microsoft Integration Runtime Configuration Manager opens (or start it from Start menu)

### Step 4.3: Retrieve the authentication key

Use the ADF that will “own” the SHIR (e.g. prod):

**Option A – Portal**

1. Azure Portal → Data Factory (e.g. `adf-tepe-prod`)
2. **Manage** → **Integration runtimes** → **+ New**
3. Choose **Azure, Self-Hosted** → **Continue**
4. Choose **Self-Hosted** → **Continue**
5. **Name:** `ir-shir-onprem-prod`
6. **Create** → a key and setup page appear; **copy the key** (Key 1 or Key 2)

**Option B – PowerShell**

```powershell
# Install Az module if needed: Install-Module -Name Az -Scope CurrentUser
Connect-AzAccount
$resourceGroup = "rg-tepe-prod"           # Your ADF resource group
$dataFactoryName = "adf-tepe-prod"        # Your ADF name
$irName = "ir-shir-onprem-prod"

$key = Get-AzDataFactoryV2IntegrationRuntimeKey `
  -ResourceGroupName $resourceGroup `
  -DataFactoryName $dataFactoryName `
  -Name $irName
$key.AuthKey1   # or AuthKey2
```

**Important:** Create the IR in the portal first (Step 4.3 Option A) if it does not exist; the PowerShell call expects the IR to already exist.

### Step 4.4: Register the SHIR with the key

1. On the SHIR VM, open **Microsoft Integration Runtime Configuration Manager**
2. **Register Integration Runtime (Self-hosted)**
3. Paste **Key 1** (or Key 2)
4. **Register**
5. Wait for “Registered successfully”
6. **Finish**

### Step 4.5: Confirm status

1. Configuration Manager → status should be **Running**
2. In ADF: **Manage** → **Integration runtimes** → `ir-shir-onprem-prod` → status **Running** with 1 node

---

## Part 5: Connect SHIR to Multiple ADF Instances (Optional)

If you have prod and dev ADF (e.g. `adf-tepe-prod`, `adf-tepe-dev`) and want one SHIR for both:

### Step 5.1: Share from primary ADF

1. ADF (primary, e.g. prod) → **Manage** → **Integration runtimes** → `ir-shir-onprem-prod`
2. **Sharing** tab → **Allow other Data Factories to use this integration runtime**
3. **Add** → select the other ADF (e.g. dev) → **Add**
4. **Save**

### Step 5.2: Create linked IR in secondary ADF

1. Open the secondary ADF (e.g. dev)
2. **Manage** → **Integration runtimes** → **+ New**
3. **Azure, Self-Hosted** → **Continue**
4. **Self-Hosted** → **Continue**
5. Choose **Perform link setup to an existing self-hosted integration runtime (SHIR)** → **Continue**
6. Pick **ir-shir-onprem-prod** from the list
7. **Name:** e.g. `ir-shir-onprem-prod` (same or different)
8. **Create**

You can now use this IR (or the linked one) in pipelines in both factories.

---

## Part 6: Create Linked Services and Pipelines

### Step 6.1: Linked service for on-premises SQL Server

1. ADF → **Manage** → **Linked services** → **+ New**
2. Search **SQL Server** → **Continue**
3. Configure:
   - **Name:** `ls_sqlserver_onprem`
   - **Connect via integration runtime:** `ir-shir-onprem-prod`
   - **Server name:** on-prem SQL FQDN or IP (reachable from the integration VNet)
   - **Database:** database name
   - **Authentication kind:** SQL Authentication (or Windows, as appropriate)
   - **User name / Password:** credentials
4. **Test connection** (must succeed from SHIR VM’s network)
5. **Create**

### Step 6.2: Linked service for Azure Data Lake Storage Gen2

1. ADF → **Manage** → **Linked services** → **+ New**
2. Search **Azure Data Lake Storage Gen2** → **Continue**
3. Configure:
   - **Name:** `ls_adls_landing`
   - **Connect via integration runtime:** `ir-shir-onprem-prod`
   - **Authentication method:** Account key (or Managed Identity if preferred)
   - **URL:** `https://<storage-account-name>.dfs.core.windows.net`
   - **Account key:** from storage account → Access keys
4. **Test connection**
5. **Create**

### Step 6.3: Copy pipeline

1. ADF → **Author** → **Pipelines** → **+ New** → **Pipeline**
2. Add activity: **Copy data**
3. **Source:**
   - Linked service: `ls_sqlserver_onprem`
   - Table or query (e.g. table name or `SELECT * FROM ...`)
4. **Sink:**
   - Linked service: `ls_adls_landing`
   - Container/path for landing zone
5. **Settings:**
   - **Enable staging:** Optional
6. **Debug** to run a test copy

---

## Part 7: Operational Checks

### Step 7.1: Enable SHIR auto-update (optional)

1. Integration Runtime Configuration Manager → **Settings**
2. Enable **Auto-update**
3. Confirm in ADF: **Manage** → **Integration runtimes** → **Capabilities** → Auto-update enabled

### Step 7.2: Log on as a service

1. On the SHIR VM: **Administrative Tools** → **Local Security Policy** → **User Rights Assignment**
2. **Log on as a service** → add `NT SERVICE\DIAHostService`

### Step 7.3: High availability (optional)

1. Install SHIR on a second VM in the same integration VNet (or another subnet with similar connectivity)
2. Use the same IR key and register as a second node
3. In IR Configuration Manager: **Settings** → enable **Remote access to intranet**

---

## Part 8: Troubleshooting

| Symptom | Possible cause | Action |
|---------|----------------|-------|
| Registration fails | Incorrect key / network | Re-copy key; check outbound 443 to Azure |
| Test connection fails (SQL) | Network/firewall | Verify SHIR VM can reach on-prem (same VNet as gateway); check NSG and firewall rules |
| Test connection fails (Storage) | Private endpoint / DNS | Verify blob + dfs PEs and DNS; confirm PE is approved; test from SHIR VM |
| IR shows “Offline” | Service not running | Restart “Integration Runtime Service” on the VM; check Event Viewer |
| Copy activity fails with timeout | Firewall / routing | Validate on-prem SQL connectivity from VM and IR account |

### Useful diagnostic commands (on SHIR VM)

```powershell
# SHIR config location
Get-ChildItem "C:\Program Files\Microsoft Integration Runtime\5.0\"

# Service status
Get-Service -Name "DIAHostService"

# Test storage connectivity
Test-NetConnection -ComputerName "<storageaccount>.blob.core.windows.net" -Port 443
```

---

## Quick reference: resource names

| Resource | Example |
|----------|---------|
| Integration VNet | vnet-int-prod-swc |
| Subnet | snet-integration-prod-swc |
| SHIR VM | vm-shir-prod-swc |
| ADF (prod) | adf-tepe-prod |
| ADF (dev) | adf-tepe-dev |
| SHIR name | ir-shir-onprem-prod |
| Blob PE | pe-storage-blob-shir |
| DFS PE | pe-storage-dfs-shir |

---

## Related documentation

- [Create self-hosted integration runtime](https://learn.microsoft.com/en-us/azure/data-factory/create-self-hosted-integration-runtime)
- [Create a shared self-hosted IR](https://learn.microsoft.com/en-us/azure/data-factory/create-shared-self-hosted-integration-runtime-powershell)
- [Azure Private Link for storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)
- [ADF on-prem ingestion cost comparison](../../ADF_ONPREM_INGESTION_COST_COMPARISON.md)
