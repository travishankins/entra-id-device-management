# Entra ID Duplicate Device Cleanup Script

## Overview

This PowerShell script identifies and removes duplicate device registrations in Entra ID (Azure AD), specifically handling the common scenario where a device is registered as both **"Azure AD registered"** and **"Azure AD hybrid joined"**.

## The Problem

When devices are both domain-joined (synced from on-premises AD) and manually registered in Azure AD, you end up with duplicate entries:

- **Azure AD hybrid joined** (TrustType: ServerAd) - Created by Azure AD Connect sync
- **Azure AD registered** (TrustType: Workplace) - Manual registration or BYOD

This creates confusion and can cause management issues.

## The Solution

This script:
1. ✅ Identifies devices with the same **DisplayName**
2. ✅ Finds cases where both trust types exist for the same device name
3. ✅ **Keeps** the Hybrid joined device (preferred for domain machines)
4. ✅ **Removes** the Registered device(s) (duplicates)
5. ✅ Generates a detailed CSV report
6. ✅ Safe by default with confirmation prompts

---

## Trust Type Reference

| Trust Type | Friendly Name | Description | Keep/Delete |
|------------|---------------|-------------|-------------|
| **ServerAd** | Azure AD hybrid joined | Domain-joined devices synced via Azure AD Connect | ✅ **KEEP** |
| **AzureAd** | Azure AD joined | Cloud-only joined devices | N/A |
| **Workplace** | Azure AD registered | Personal/BYOD devices or duplicate registrations | ❌ **DELETE** (if duplicate) |

---

## Requirements

### PowerShell Version
- PowerShell 7+ (recommended)
- Windows PowerShell 5.1+ (supported)

### Microsoft Graph PowerShell SDK
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Required Permissions
- **Read/Report only**: `Device.Read.All` or `Directory.Read.All`
- **Deletion**: `Device.ReadWrite.All`

You'll be prompted to consent to these permissions on first run.

---

## Usage Examples

### 1. Generate Report Only (Safe - No Deletion)
```powershell
.\delete-duplicate-device.ps1
```
This will:
- Connect to Microsoft Graph
- Find all duplicate devices
- Generate a CSV report
- **NOT delete anything**

### 2. Delete Duplicates with Confirmation
```powershell
.\delete-duplicate-device.ps1 -Delete
```
This will:
- Find duplicates
- Show you the first 10 devices to be deleted
- Ask you to type "DELETE" to confirm
- Delete the registered duplicates

### 3. Delete Without Confirmation (Automated)
```powershell
.\delete-duplicate-device.ps1 -Delete -Force
```
⚠️ **USE WITH CAUTION!** This will delete without asking for confirmation.

### 4. Preview What Would Be Deleted (WhatIf)
```powershell
.\delete-duplicate-device.ps1 -Delete -WhatIf
```
Shows what would be deleted without actually deleting anything.

### 5. Only Delete Old Registered Devices
```powershell
.\delete-duplicate-device.ps1 -Delete -MinimumDaysOld 30
```
Only deletes registered devices that are at least 30 days old (safety measure).

### 6. Custom Report Path
```powershell
.\delete-duplicate-device.ps1 -ReportPath "C:\Reports\duplicates.csv"
```

### 7. Server Authentication (No Browser)
```powershell
.\delete-duplicate-device.ps1 -NoBrowser
```
Uses device code authentication for servers without browsers.

---

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ReportPath` | String | No | `.\EntraDevices_DuplicateCleanup_<timestamp>.csv` | Path for the CSV report |
| `-Delete` | Switch | No | False | Actually delete devices (otherwise report-only) |
| `-Force` | Switch | No | False | Skip confirmation prompts |
| `-NoBrowser` | Switch | No | False | Use device code authentication |
| `-MinimumDaysOld` | Int | No | 0 | Only delete registered devices older than X days |

---

## Output Files

### CSV Report
**Filename**: `EntraDevices_DuplicateCleanup_YYYYMMDD_HHMMSS.csv`

**Contains:**
- ObjectId
- DeviceId
- DisplayName
- OperatingSystem
- OperatingSystemVersion
- TrustType / TrustTypeFriendly
- DeviceOwnership
- AccountEnabled
- RegistrationDateTimeUtc
- CreatedDateTimeUtc
- ApproximateLastSignInDateTimeUtc
- AgeInDays
- Reason (why it's being deleted)
- HybridDeviceCount (how many hybrid versions exist)

### Error Log (if deletions fail)
**Filename**: `EntraDevices_DuplicateDeleteErrors_YYYYMMDD_HHMMSS.log`

Contains details of any devices that failed to delete.

---

## How It Works

### Step 1: Connect to Microsoft Graph
Authenticates with appropriate permissions.

### Step 2: Retrieve All Devices
Fetches all devices from Entra ID with relevant properties.

### Step 3: Analyze for Duplicates
- Groups devices by DisplayName
- Finds groups with multiple registrations
- Identifies groups containing both:
  - At least one "Azure AD hybrid joined" device (ServerAd)
  - At least one "Azure AD registered" device (Workplace)

### Step 4: Filter by Age (Optional)
If `-MinimumDaysOld` is specified, only includes registered devices older than the threshold.

### Step 5: Generate Report
Exports all identified duplicates to CSV.

### Step 6: Delete (if requested)
If `-Delete` is specified:
- Shows preview of devices to be deleted
- Asks for confirmation (unless `-Force`)
- Deletes each registered duplicate
- Shows progress and summary

### Step 7: Cleanup
Disconnects from Microsoft Graph.

---

## Safety Features

### 1. ✅ Report-First Approach
By default, only generates a report - no deletion unless `-Delete` is specified.

### 2. ✅ Confirmation Required
Must type "DELETE" (all caps) to proceed unless `-Force` is used.

### 3. ✅ Preview Before Delete
Shows first 10 devices before deletion for review.

### 4. ✅ WhatIf Support
Fully supports `-WhatIf` for testing.

### 5. ✅ Age Filter
Can specify `-MinimumDaysOld` to avoid deleting recently registered devices.

### 6. ✅ Detailed Logging
All actions and errors are logged with timestamps.

### 7. ✅ Only Deletes Registered Duplicates
Never touches the hybrid joined version - only removes registered duplicates.

---

## Example Workflow

### Recommended Safe Workflow:

**Step 1: Generate initial report**
```powershell
.\delete-duplicate-device.ps1
```
Review the CSV to understand what would be deleted.

**Step 2: Test with WhatIf**
```powershell
.\delete-duplicate-device.ps1 -Delete -WhatIf
```
See what would happen without making changes.

**Step 3: Delete with confirmation**
```powershell
.\delete-duplicate-device.ps1 -Delete
```
Review the preview, type "DELETE" to confirm.

**Step 4: Verify results**
Check the deletion summary and review any error logs.

---

## Common Scenarios

### Scenario 1: Domain-Joined Machine Manually Registered
**Before:**
- DESKTOP-ABC (Azure AD hybrid joined) ✅ Created by AAD Connect
- DESKTOP-ABC (Azure AD registered) ❌ Manually registered by user

**After Script:**
- DESKTOP-ABC (Azure AD hybrid joined) ✅ KEPT
- ~~DESKTOP-ABC (Azure AD registered)~~ ❌ DELETED

### Scenario 2: Multiple Registered Duplicates
**Before:**
- LAPTOP-XYZ (Azure AD hybrid joined) ✅ 
- LAPTOP-XYZ (Azure AD registered) ❌ First duplicate
- LAPTOP-XYZ (Azure AD registered) ❌ Second duplicate

**After Script:**
- LAPTOP-XYZ (Azure AD hybrid joined) ✅ KEPT
- ~~All registered versions deleted~~ ❌ DELETED

### Scenario 3: No Hybrid Version (Safe)
**Before:**
- BYOD-123 (Azure AD registered) - User's personal device

**After Script:**
- BYOD-123 (Azure AD registered) ✅ KEPT (no hybrid version, not a duplicate)

---

## Troubleshooting

### Issue: "No devices found"
**Solution:** Verify you have the correct permissions and are connected to the right tenant.

### Issue: "Failed to connect to Microsoft Graph"
**Solution:** 
1. Install the module: `Install-Module Microsoft.Graph`
2. Try `-NoBrowser` parameter if on a server

### Issue: Deletions fail
**Possible causes:**
- Insufficient permissions (need Device.ReadWrite.All)
- Device is managed by Intune with deletion protection
- Device is being actively used

**Solution:** Check the error log for specific failure reasons.

### Issue: Script identifies wrong devices
**Verification:**
1. Check the CSV report carefully
2. Use `-WhatIf` to preview
3. Use `-MinimumDaysOld` to add safety buffer
4. Start with a test tenant if possible

---

## Best Practices

1. ✅ **Always run report-only first** to see what will be affected
2. ✅ **Use WhatIf** before actual deletion
3. ✅ **Review the CSV** to ensure only duplicates are targeted
4. ✅ **Start with `-MinimumDaysOld 30`** to avoid recent registrations
5. ✅ **Run during maintenance window** to minimize user impact
6. ✅ **Keep the CSV reports** for audit purposes
7. ✅ **Test in dev/test environment** first if available
8. ✅ **Communicate with users** about device cleanup

---

## Script Comparison

### This Script vs. Inactive Device Cleanup Script

| Feature | Duplicate Cleanup | Inactive Cleanup |
|---------|------------------|------------------|
| **Purpose** | Remove duplicate registrations | Remove old/inactive devices |
| **Criteria** | Same DisplayName + different trust types | Days inactive |
| **What's deleted** | Registered duplicates only | Any device type if inactive |
| **Safety filter** | Keeps hybrid joined | Age-based filter |
| **Use case** | Clean up registration duplicates | Remove stale devices |

Both scripts can be used together for comprehensive device hygiene!

---

## Support & Version Info

- **Version**: 1.0
- **Last Updated**: October 3, 2025
- **PowerShell Version**: 7+ recommended, 5.1+ supported
- **Graph API Version**: v1.0 (via Microsoft.Graph PowerShell SDK)

---

## License & Disclaimer

This script is provided as-is without warranty. Always test in a non-production environment first. The script has built-in safety features, but you are responsible for reviewing actions before deletion.
