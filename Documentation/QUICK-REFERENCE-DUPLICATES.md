# Quick Reference - Duplicate Device Cleanup

## What Does This Script Do?

Finds devices with the same name that are registered BOTH as:
- **Hybrid joined** (domain-joined, synced from on-prem AD) 
- **Registered** (manually registered)

Then **deletes the "Registered" version** and **keeps the "Hybrid joined" version**.

---

## Quick Start

### 1. First Time - Just Report (Safe!)
```powershell
.\delete-duplicate-device.ps1
```
✅ No deletion - just shows what duplicates exist

### 2. Delete Duplicates (With Confirmation)
```powershell
.\delete-duplicate-device.ps1 -Delete
```
⚠️ Will ask you to type "DELETE" before proceeding

### 3. Automated (No Confirmation)
```powershell
.\delete-duplicate-device.ps1 -Delete -Force
```
🚨 **DANGER!** Deletes without asking

---

## Common Commands

```powershell
# Preview what would be deleted
.\delete-duplicate-device.ps1 -Delete -WhatIf

# Only delete devices older than 30 days
.\delete-duplicate-device.ps1 -Delete -MinimumDaysOld 30

# Save report to specific location
.\delete-duplicate-device.ps1 -ReportPath "C:\Reports\duplicates.csv"

# For servers without browser
.\delete-duplicate-device.ps1 -NoBrowser
```

---

## What Gets Deleted?

### ❌ DELETED (Registered duplicate)
```
Device: DESKTOP-ABC
Trust Type: Azure AD registered
Reason: Duplicate of hybrid joined device
```

### ✅ KEPT (Hybrid joined)
```
Device: DESKTOP-ABC
Trust Type: Azure AD hybrid joined
Reason: Preferred version for domain-joined devices
```

---

## Safety Checklist

- [ ] Run report-only first (no `-Delete` flag)
- [ ] Review the CSV file carefully
- [ ] Test with `-WhatIf` parameter
- [ ] Consider using `-MinimumDaysOld 30` for safety
- [ ] Type "DELETE" when prompted (double-check!)
- [ ] Review deletion summary after completion

---

## Trust Types Explained

| Type | What It Means | Keep or Delete? |
|------|---------------|-----------------|
| **ServerAd** | Hybrid joined (synced from AD) | ✅ **KEEP** |
| **Workplace** | Registered (manual/BYOD) | ❌ **DELETE** (if duplicate) |
| **AzureAd** | Cloud-only joined | N/A (not affected) |

---

## Permissions Needed

**Report Only:**
- Device.Read.All

**Deletion:**
- Device.ReadWrite.All

You'll be prompted to consent on first run.

---

## Output Files

**Success Report:**
`EntraDevices_DuplicateCleanup_20251003_143022.csv`

**Error Log (if failures occur):**
`EntraDevices_DuplicateDeleteErrors_20251003_143022.log`

---

## Troubleshooting

**"No devices found"**
→ Check permissions and tenant connection

**"Failed to connect"**
→ Install module: `Install-Module Microsoft.Graph`

**Deletions fail**
→ Check the error log file for specific reasons

**Too many duplicates found**
→ Use `-MinimumDaysOld` to filter by age first

---

## Example Output

```
================================================================================
Entra ID Duplicate Device Cleanup Script
================================================================================
Purpose: Remove 'Registered' devices when 'Hybrid joined' version exists
================================================================================
Connecting to Microsoft Graph with scopes: Device.Read.All
Connected. TenantId: abc123... - Account: admin@contoso.com

Fetching all devices from Entra ID (this may take a moment)...
Retrieved 1,247 total devices from Entra ID.

Analyzing devices for duplicates...
Found 15 device names with multiple registrations.
  [1] 'DESKTOP-ABC' - Found 1 Hybrid + 1 Registered
  [2] 'LAPTOP-XYZ' - Found 1 Hybrid + 2 Registered
  ...

Identified 23 registered device(s) to remove (duplicates of hybrid joined devices).

Summary:
  Total devices in tenant: 1,247
  Duplicate registered devices found: 23

Report written: .\EntraDevices_DuplicateCleanup_20251003_143530.csv (23 devices)
Full path: /Users/admin/Downloads/EntraDevices_DuplicateCleanup_20251003_143530.csv

No devices were deleted (report-only mode).
Review the report at: .\EntraDevices_DuplicateCleanup_20251003_143530.csv
To delete these duplicate devices, re-run with the -Delete switch.

Disconnected from Microsoft Graph.

Script completed.
```

---

## Remember

1. **Report first, delete later**
2. **Review the CSV carefully**
3. **Use -WhatIf to test**
4. **Keep audit logs**
5. **Communicate with your team**

---

**Need more details?** See the full README: `DELETE-DUPLICATE-DEVICE-README.md`
