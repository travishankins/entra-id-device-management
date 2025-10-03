# Entra ID Device Management Toolkit

PowerShell toolkit for managing and cleaning up Microsoft Entra ID (Azure AD) device registrations - remove inactive devices and resolve duplicates.

## 🎯 Purpose

This toolkit helps IT administrators maintain clean and accurate device inventories in Microsoft Entra ID by:
- 🧹 Removing inactive or abandoned devices
- 🔄 Eliminating duplicate device registrations
- 💰 Reducing licensing costs (Intune, etc.)
- 🔒 Improving security posture
- 📊 Ensuring accurate reporting

## � What's Inside

| Script | Purpose | Use When |
|--------|---------|----------|
| **delete-duplicate-device.ps1** | Removes duplicate registrations (keeps Hybrid joined, removes Registered) | Fixing registration conflicts after AD Connect |
| **delete-entra-devices.ps1** | Removes devices inactive for X days | Quarterly cleanup, offboarding, license reduction |

**Documentation:**
- `Documentation/SCRIPT-COMPARISON-GUIDE.md` - When to use which script
- `Documentation/DELETE-DUPLICATE-DEVICE-README.md` - Detailed duplicate cleanup guide
- `Documentation/QUICK-REFERENCE-DUPLICATES.md` - One-page cheat sheet

---

## 🚀 Quick Start (5 Minutes)

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Prerequisites (One-time)
```powershell
# Install Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser

# Import the module
Import-Module Microsoft.Graph
```

**Required Permissions:**
- Read-only: `Device.Read.All`
- Deletion: `Device.ReadWrite.All`

### Step 2: Navigate to Scripts
```powershell
cd path/to/entra-id-device-management/Scripts
```

### Step 3: Run Your First Report (Safe - No Deletion)

**Option A - Find Duplicate Devices:**
```powershell
./delete-duplicate-device.ps1
# Creates CSV report: EntraDevices_DuplicateCleanup_YYYYMMDD_HHMMSS.csv
```

**Option B - Find Inactive Devices:**
```powershell
./delete-entra-devices.ps1 -DaysInactive 90
# Creates CSV report: EntraDevices_Inactive_YYYYMMDD_HHMMSS.csv
```

### Step 4: Review CSV → Then Delete

After reviewing the CSV report, delete if needed:

```powershell
# Test what would be deleted (safe)
./delete-duplicate-device.ps1 -Delete -WhatIf

# Actually delete (requires typing 'DELETE' to confirm)
./delete-duplicate-device.ps1 -Delete
```

---

## 📋 Common Usage Scenarios

### Scenario 1: New Tenant Cleanup
```powershell
# Week 1: Discover what needs cleanup
./delete-duplicate-device.ps1
./delete-entra-devices.ps1 -DaysInactive 180

# Week 2: Review CSVs, communicate with team, then execute
./delete-duplicate-device.ps1 -Delete
./delete-entra-devices.ps1 -DaysInactive 180 -Delete
```

### Scenario 2: Monthly Maintenance
```powershell
# First Monday of each month
./delete-duplicate-device.ps1 -Delete
./delete-entra-devices.ps1 -DaysInactive 90 -Delete
```

### Scenario 3: After Employee Offboarding
```powershell
# Remove recently inactive devices
./delete-entra-devices.ps1 -DaysInactive 30 -IncludeDisabled -Delete
```

---

## ⚙️ Command Reference

### Duplicate Device Cleanup
```powershell
# Basic report
./delete-duplicate-device.ps1

# Only delete duplicates older than 30 days
./delete-duplicate-device.ps1 -Delete -MinimumDaysOld 30

# Preview deletion (no actual changes)
./delete-duplicate-device.ps1 -Delete -WhatIf

# Automated deletion without confirmation (careful!)
./delete-duplicate-device.ps1 -Delete -Force

# Use device code authentication (for servers)
./delete-duplicate-device.ps1 -NoBrowser
```

### Inactive Device Cleanup
```powershell
# Report devices inactive for 90+ days
./delete-entra-devices.ps1 -DaysInactive 90

# Include devices that never signed in
./delete-entra-devices.ps1 -DaysInactive 180 -IncludeNullSignIn

# Include disabled devices
./delete-entra-devices.ps1 -DaysInactive 90 -IncludeDisabled

# Delete with confirmation
./delete-entra-devices.ps1 -DaysInactive 180 -Delete

# Preview deletion
./delete-entra-devices.ps1 -DaysInactive 90 -Delete -WhatIf

# Custom report path
./delete-entra-devices.ps1 -DaysInactive 90 -ReportPath "./reports/my-report.csv"
```

---

## 🛡️ Safety Features

Both scripts are designed with safety in mind:

✅ **Report-first approach** - Always generates CSV before any deletion  
✅ **Confirmation prompts** - Must type "DELETE" to confirm (unless -Force)  
✅ **WhatIf support** - Test deletions without making changes  
✅ **Detailed logging** - CSV reports with timestamps  
✅ **Error tracking** - Separate error logs for failed deletions  
✅ **Progress indicators** - Real-time feedback during execution

---

## 📊 Understanding Output Files

Scripts generate timestamped files in the current directory:

| File Pattern | Content | When Created |
|--------------|---------|--------------|
| `EntraDevices_Inactive_*.csv` | Devices inactive for X days | After running delete-entra-devices.ps1 |
| `EntraDevices_DuplicateCleanup_*.csv` | Duplicate registrations found | After running delete-duplicate-device.ps1 |
| `EntraDevices_DeleteErrors_*.log` | Failed deletions (if any) | Only if deletion errors occur |

**Example CSV columns:**
- `DisplayName` - Device name
- `TrustType` - How device is joined (Hybrid/Registered/Joined)
- `InactiveDays` - Days since last sign-in
- `LastSignIn` - Last activity timestamp
- `AccountEnabled` - Active or disabled
- `DeviceId` - Unique device identifier

---

## 💡 Best Practices

### Before Running in Production

1. **Test in report mode first** ✓
   ```powershell
   # Always run without -Delete first
   ./delete-entra-devices.ps1 -DaysInactive 90
   ```

2. **Use WhatIf for preview** ✓
   ```powershell
   ./delete-duplicate-device.ps1 -Delete -WhatIf
   ```

3. **Start conservative** ✓
   - Begin with high day counts (180+ days)
   - Use `-MinimumDaysOld` on duplicate cleanup
   - Gradually tighten criteria

4. **Communicate changes** ✓
   - Notify IT team before running
   - Inform stakeholders about cleanup policies
   - Document actions in change management system

5. **Keep audit trail** ✓
   - Save all CSV reports
   - Archive deletion logs
   - Document rationale for deletions

### Recommended Maintenance Schedule

| Frequency | Task |
|-----------|------|
| **Monthly** | Run duplicate device cleanup |
| **Quarterly** | Run inactive device cleanup (90-180 days) |
| **As Needed** | After AD Connect deployment, org changes, or policy updates |

---

## � Authentication & Permissions

---

## 🔑 Authentication & Permissions

### First Time Authentication
When you run a script for the first time:
```powershell
# Browser-based authentication (default)
./delete-duplicate-device.ps1

# Device code authentication (for servers without browser)
./delete-duplicate-device.ps1 -NoBrowser
```

You'll be prompted to sign in and consent to permissions.

### Required Permissions

| Action | Permission Needed | Scope |
|--------|------------------|-------|
| **Report Only** | `Device.Read.All` | Read device information |
| **Delete Devices** | `Device.ReadWrite.All` | Read and delete devices |

Admin consent is required for these permissions.

### Testing Connectivity
```powershell
# Test connection
Connect-MgGraph -Scopes "Device.Read.All"
Get-MgDevice -Top 10
Get-MgContext  # Shows current tenant
Disconnect-MgGraph
```
---

## 📚 Additional Documentation

Detailed guides available in the `Documentation/` folder:

- **[SCRIPT-COMPARISON-GUIDE.md](Documentation/SCRIPT-COMPARISON-GUIDE.md)** - When to use which script
- **[DELETE-DUPLICATE-DEVICE-README.md](Documentation/DELETE-DUPLICATE-DEVICE-README.md)** - Comprehensive duplicate cleanup guide  
- **[QUICK-REFERENCE-DUPLICATES.md](Documentation/QUICK-REFERENCE-DUPLICATES.md)** - One-page cheat sheet
- **[SCRIPT_IMPROVEMENTS.md](Documentation/SCRIPT_IMPROVEMENTS.md)** - Version history and changelog

---

## ⚠️ Important Notes

### Safety Considerations

- ✓ **Always test in non-production first** if possible
- ✓ **Review CSV reports thoroughly** before deletion
- ✓ **Use WhatIf** to preview actions
- ✓ **Start conservative** (high day counts, age restrictions)
- ✓ **Keep backups** of all reports for audit trail
- ✓ **Follow change management** procedures

### What Gets Deleted

**delete-duplicate-device.ps1:**
- Only deletes "Azure AD registered" devices
- Keeps "Azure AD hybrid joined" devices (preferred)
- Requires both trust types exist for same device name

**delete-entra-devices.ps1:**
- Deletes devices inactive beyond specified days
- Can include devices with null sign-in dates (optional)
- Can include disabled devices (optional)
---

## ⚙️ Technical Details

**PowerShell Version:** 7+ recommended, 5.1+ supported  
**Graph API Version:** v1.0 (via Microsoft.Graph PowerShell SDK)  
**Last Updated:** October 3, 2025

---

## 🚦 Quick Reference

### Need to...
- **Clean up duplicates?** → `./delete-duplicate-device.ps1`
- **Remove old devices?** → `./delete-entra-devices.ps1 -DaysInactive 180`
- **Just see what's there?** → Run either script without `-Delete`
- **Test before deleting?** → Add `-WhatIf` to any delete command
- **Automate cleanup?** → Use `-Force` (but be careful!)



**Built with ❤️ following Microsoft Entra best practices**