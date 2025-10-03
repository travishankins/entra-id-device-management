# Quick Start Guide - Entra ID Device Management

## 🚀 Getting Started in 5 Minutes

### Step 1: Install Requirements (One-time setup)
```powershell
# Install Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser

# Import the module
Import-Module Microsoft.Graph
```

### Step 2: Navigate to Scripts
```powershell
cd ~/Developer/EntraID-Device-Management/Scripts
```

### Step 3: Choose Your Task

#### Task A: Find Duplicate Devices
```powershell
# Run report (safe - no deletion)
./delete-duplicate-device.ps1

# Check the CSV file created in current directory
# Review it before proceeding
```

#### Task B: Find Inactive Devices
```powershell
# Find devices inactive for 90+ days (safe - no deletion)
./delete-entra-devices.ps1 -DaysInactive 90

# Check the CSV file created
# Review it before proceeding
```

### Step 4: Delete After Review

#### If you want to remove duplicates:
```powershell
# Test first (shows what would happen)
./delete-duplicate-device.ps1 -Delete -WhatIf

# Actually delete (with confirmation)
./delete-duplicate-device.ps1 -Delete
# Type 'DELETE' when prompted
```

#### If you want to remove inactive devices:
```powershell
# Test first
./delete-entra-devices.ps1 -DaysInactive 90 -Delete -WhatIf

# Actually delete (with confirmation)
./delete-entra-devices.ps1 -DaysInactive 90 -Delete
# Type 'DELETE' when prompted
```

---

## 📋 Common Scenarios

### Scenario 1: New to this tenant, clean up everything
```powershell
# Day 1: Discover
./delete-duplicate-device.ps1
./delete-entra-devices.ps1 -DaysInactive 180

# Day 2-7: Review CSVs, communicate with team

# Day 8: Execute
./delete-duplicate-device.ps1 -Delete
./delete-entra-devices.ps1 -DaysInactive 180 -Delete
```

### Scenario 2: Monthly maintenance
```powershell
# First Monday of month
./delete-duplicate-device.ps1 -Delete

# Check for devices inactive 90+ days
./delete-entra-devices.ps1 -DaysInactive 90 -Delete
```

### Scenario 3: After employee termination
```powershell
# Remove devices inactive for 30+ days
./delete-entra-devices.ps1 -DaysInactive 30 -IncludeDisabled -Delete
```

---

## 🎯 What Each Script Does

| Script | Finds | Deletes | Best For |
|--------|-------|---------|----------|
| **delete-duplicate-device.ps1** | Same device name with different trust types | Registered duplicates | Cleaning registration issues |
| **delete-entra-devices.ps1** | Devices not used in X days | Any inactive device | Removing old/abandoned devices |

---

## ⚠️ Safety Checklist

Before deleting anything:
- [ ] Run in report mode first (without `-Delete`)
- [ ] Review the CSV file completely
- [ ] Test with `-WhatIf` parameter
- [ ] Communicate with team
- [ ] Have backup/rollback plan
- [ ] Start with conservative settings (high day counts)

---

## 🔑 Authentication

First time running a script:
```powershell
# You'll see a browser window for authentication
# Sign in with admin account
# Consent to permissions when prompted
```

On servers without browser:
```powershell
# Use device code authentication
./delete-duplicate-device.ps1 -NoBrowser
./delete-entra-devices.ps1 -DaysInactive 90 -NoBrowser
```

---

## 📊 Understanding the Output

### CSV Reports
**Location:** Current directory (Scripts folder)
**Filename pattern:** `EntraDevices_*_YYYYMMDD_HHMMSS.csv`

**What to look for:**
- DisplayName - Device names
- TrustType - How device is joined
- InactiveDays - How long since last use
- AccountEnabled - If device is active

### Console Output
- **Green** ✓ = Success
- **Yellow** ⚠️ = Warning/Info
- **Red** ✗ = Error
- **Cyan** ℹ️ = Information

---

## 🆘 Quick Troubleshooting

### "Connect-MgGraph not recognized"
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Import-Module Microsoft.Graph
```

### "Insufficient privileges"
You need `Device.ReadWrite.All` permission. Admin must consent.

### "No devices found"
Check you're connected to the right tenant:
```powershell
Connect-MgGraph -Scopes "Device.Read.All"
Get-MgContext  # Shows current tenant
```

### Scripts won't run (execution policy)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📚 Need More Details?

- **Full documentation:** `../Documentation/`
- **Script comparison:** `../Documentation/SCRIPT-COMPARISON-GUIDE.md`
- **Duplicate cleanup guide:** `../Documentation/DELETE-DUPLICATE-DEVICE-README.md`
- **Quick reference:** `../Documentation/QUICK-REFERENCE-DUPLICATES.md`

---

## 🎓 Pro Tips

1. **Always start with reports** - Never delete on first run
2. **Use high day counts initially** - 180+ days is safer
3. **Test with -WhatIf** - See what would happen
4. **Save your CSV reports** - Keep for audit trail
5. **Run duplicates first** - Then inactive (cleaner data)

---

**Ready to start?** Pick a script above and run in report mode! 🚀
