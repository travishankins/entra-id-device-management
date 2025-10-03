# Entra ID Device Management Toolkit

A collection of PowerShell scripts for managing and maintaining a clean Microsoft Entra ID (Azure AD) device inventory.

## 📁 Project Structure

```
EntraID-Device-Management/
├── README.md                          # This file - project overview
├── Scripts/                           # PowerShell scripts
│   ├── delete-entra-devices.ps1      # Remove inactive/stale devices
│   └── delete-duplicate-device.ps1   # Remove duplicate device registrations
└── Documentation/                     # Comprehensive guides
    ├── SCRIPT-COMPARISON-GUIDE.md    # When to use which script
    ├── DELETE-DUPLICATE-DEVICE-README.md
    ├── QUICK-REFERENCE-DUPLICATES.md
    └── SCRIPT_IMPROVEMENTS.md
```

## 🎯 Purpose

This toolkit helps IT administrators maintain clean and accurate device inventories in Microsoft Entra ID by:
- Removing inactive or abandoned devices
- Eliminating duplicate device registrations
- Reducing licensing costs
- Improving security posture
- Ensuring accurate reporting

## 📜 Available Scripts

### 1. **delete-entra-devices.ps1** - Inactive Device Cleanup
Removes devices that haven't been used in a specified number of days.

**Use Cases:**
- Quarterly device cleanup
- Removing devices from former employees
- Reducing Intune license costs
- Security hygiene

**Quick Start:**
```powershell
# Report only
./Scripts/delete-entra-devices.ps1 -DaysInactive 90

# Delete devices inactive for 180+ days
./Scripts/delete-entra-devices.ps1 -DaysInactive 180 -Delete
```

### 2. **delete-duplicate-device.ps1** - Duplicate Device Cleanup
Removes "Azure AD registered" devices when "Azure AD hybrid joined" versions exist.

**Use Cases:**
- Fixing duplicate registrations after AD Connect deployment
- Cleaning up manual registrations
- Resolving Conditional Access conflicts

**Quick Start:**
```powershell
# Report only
./Scripts/delete-duplicate-device.ps1

# Delete duplicates with confirmation
./Scripts/delete-duplicate-device.ps1 -Delete
```

## 🚀 Quick Start Guide

### Prerequisites
1. **PowerShell 7+** (or Windows PowerShell 5.1+)
2. **Microsoft Graph PowerShell SDK:**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```
3. **Permissions:**
   - Read-only: `Device.Read.All`
   - Deletion: `Device.ReadWrite.All`

### First Time Setup
```powershell
# Navigate to project folder
cd ~/Developer/EntraID-Device-Management

# Install Microsoft Graph module if needed
Install-Module Microsoft.Graph -Scope CurrentUser

# Test connectivity
Connect-MgGraph -Scopes "Device.Read.All"
Get-MgDevice -Top 10
Disconnect-MgGraph
```

### Recommended Workflow
```powershell
# Step 1: Remove duplicates first (safer, smaller scope)
./Scripts/delete-duplicate-device.ps1
# Review CSV, then:
./Scripts/delete-duplicate-device.ps1 -Delete

# Step 2: Clean up inactive devices
./Scripts/delete-entra-devices.ps1 -DaysInactive 180
# Review CSV, then:
./Scripts/delete-entra-devices.ps1 -DaysInactive 180 -Delete
```

## 📚 Documentation

### Quick References
- **[QUICK-REFERENCE-DUPLICATES.md](Documentation/QUICK-REFERENCE-DUPLICATES.md)** - One-page cheat sheet for duplicate cleanup

### Detailed Guides
- **[SCRIPT-COMPARISON-GUIDE.md](Documentation/SCRIPT-COMPARISON-GUIDE.md)** - When to use which script
- **[DELETE-DUPLICATE-DEVICE-README.md](Documentation/DELETE-DUPLICATE-DEVICE-README.md)** - Full duplicate cleanup guide
- **[SCRIPT_IMPROVEMENTS.md](Documentation/SCRIPT_IMPROVEMENTS.md)** - Version history and improvements

## ⚙️ Common Commands

### Inactive Device Cleanup
```powershell
# Report devices inactive for 90+ days
./Scripts/delete-entra-devices.ps1 -DaysInactive 90

# Include devices that never signed in
./Scripts/delete-entra-devices.ps1 -DaysInactive 180 -IncludeNullSignIn

# Delete with confirmation
./Scripts/delete-entra-devices.ps1 -DaysInactive 180 -Delete

# Preview what would be deleted
./Scripts/delete-entra-devices.ps1 -DaysInactive 90 -Delete -WhatIf
```

### Duplicate Device Cleanup
```powershell
# Find duplicates (report only)
./Scripts/delete-duplicate-device.ps1

# Delete duplicates older than 30 days
./Scripts/delete-duplicate-device.ps1 -Delete -MinimumDaysOld 30

# Preview deletion
./Scripts/delete-duplicate-device.ps1 -Delete -WhatIf

# Automated deletion (no confirmation)
./Scripts/delete-duplicate-device.ps1 -Delete -Force
```

## 🛡️ Safety Features

Both scripts include:
- ✅ **Report-first approach** - Generate reports before deletion
- ✅ **Confirmation prompts** - Must type "DELETE" to confirm
- ✅ **WhatIf support** - Test without making changes
- ✅ **Detailed logging** - CSV reports and error logs
- ✅ **Progress tracking** - Visual feedback during execution
- ✅ **Error handling** - Comprehensive try-catch blocks

## 📊 Output Files

Scripts generate timestamped files:
- **CSV Reports:** `EntraDevices_*.csv` - Devices identified for action
- **Error Logs:** `EntraDevices_*Errors_*.log` - Deletion failures (if any)

Example:
```
EntraDevices_Inactive_20251003_143022.csv
EntraDevices_DuplicateCleanup_20251003_150145.csv
EntraDevices_DeleteErrors_20251003_143530.log
```

## 🔒 Permissions Required

### For Reporting (Read-Only)
- `Device.Read.All` or `Directory.Read.All`

### For Deletion
- `Device.ReadWrite.All`

Permissions are requested when you run the script for the first time.

## 💡 Best Practices

1. **Always run in report mode first**
   ```powershell
   # Good: Review before deleting
   ./Scripts/delete-entra-devices.ps1 -DaysInactive 90
   # Then delete after review
   ./Scripts/delete-entra-devices.ps1 -DaysInactive 90 -Delete
   ```

2. **Use WhatIf for testing**
   ```powershell
   ./Scripts/delete-duplicate-device.ps1 -Delete -WhatIf
   ```

3. **Start conservative**
   - Begin with high day counts (180+ days)
   - Use age filters on duplicate cleanup
   - Gradually tighten criteria

4. **Keep audit logs**
   - Save all CSV reports
   - Document actions taken
   - Maintain deletion logs

5. **Communicate changes**
   - Notify IT team before running
   - Inform users about cleanup policies
   - Set expectations

## 🗓️ Recommended Maintenance Schedule

### Monthly
- Run duplicate device cleanup
- Review reports for patterns

### Quarterly
- Run inactive device cleanup (90-180 days)
- Delete after review and approval

### After Major Changes
- After Azure AD Connect deployment
- After organizational mergers
- After policy changes

## 🧪 Testing

Before production use:
```powershell
# 1. Test connectivity
Connect-MgGraph -Scopes "Device.Read.All"

# 2. Run in report mode
./Scripts/delete-duplicate-device.ps1

# 3. Test with WhatIf
./Scripts/delete-duplicate-device.ps1 -Delete -WhatIf

# 4. Test in small batch (if available)
./Scripts/delete-entra-devices.ps1 -DaysInactive 365 -Delete

# 5. Review all outputs before scaling up
```

## ❓ Troubleshooting

### "Failed to connect to Microsoft Graph"
**Solution:**
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Import-Module Microsoft.Graph
```

### "Insufficient privileges"
**Solution:** You need `Device.ReadWrite.All` permission for deletion.

### "No devices found"
**Solution:** Check that you're connected to the correct tenant.

### Script execution policy errors
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📝 Version History

- **v2.0** (Oct 2025) - Enhanced error handling, improved reporting
- **v1.0** (Oct 2025) - Initial release with both scripts

## 🤝 Support

For issues or questions:
1. Review the detailed documentation in the `Documentation/` folder
2. Check the troubleshooting section above
3. Review CSV reports for specific error messages

## ⚠️ Disclaimer

These scripts are provided as-is without warranty. Always:
- Test in a non-production environment first
- Review reports before deletion
- Keep backups of important data
- Follow your organization's change management procedures

## 📄 License

These scripts are for internal IT administration use.

---

**Last Updated:** October 3, 2025
**PowerShell Version:** 7+ recommended, 5.1+ supported
**Graph API Version:** v1.0 (via Microsoft.Graph PowerShell SDK)
