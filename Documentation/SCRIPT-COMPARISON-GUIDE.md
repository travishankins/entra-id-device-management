# Entra ID Device Cleanup Scripts - Comparison Guide

## Two Scripts for Different Purposes

You now have **two complementary scripts** for maintaining clean Entra ID device inventory:

---

## Script 1: Inactive Device Cleanup
**File:** `delete-entra-devices.ps1`

### Purpose
Remove devices that haven't been used in a long time (stale/abandoned devices).

### Criteria for Deletion
- Devices **inactive** for X days (you specify)
- Optionally: devices that **never signed in**
- Based on `approximateLastSignInDateTime`

### What Gets Deleted
ANY device type (Hybrid, Joined, or Registered) if it meets the inactivity criteria.

### Best For
- Cleaning up old/abandoned devices
- Removing devices from former employees
- Reducing license costs
- Security hygiene (removing unused endpoints)

### Key Parameters
```powershell
-DaysInactive 90           # Required: how many days inactive
-IncludeNullSignIn        # Include never-signed-in devices
-IncludeDisabled          # Include disabled devices
-Delete                   # Actually delete (vs. report only)
-Force                    # Skip confirmation
```

### Example Use Cases
```powershell
# Remove devices inactive for 180+ days
.\delete-entra-devices.ps1 -DaysInactive 180 -Delete

# Clean up devices that never signed in
.\delete-entra-devices.ps1 -DaysInactive 365 -IncludeNullSignIn -Delete

# Report on devices inactive for 90+ days
.\delete-entra-devices.ps1 -DaysInactive 90
```

---

## Script 2: Duplicate Device Cleanup
**File:** `delete-duplicate-device.ps1`

### Purpose
Remove duplicate registrations when a device exists as both "Hybrid joined" AND "Registered".

### Criteria for Deletion
- Devices with the **same DisplayName**
- Where BOTH trust types exist:
  - Azure AD hybrid joined (ServerAd) ✅ KEEP
  - Azure AD registered (Workplace) ❌ DELETE

### What Gets Deleted
ONLY "Azure AD registered" devices that have a "Hybrid joined" duplicate.

### Best For
- Fixing duplicate device registrations
- Cleaning up after migration from registered to hybrid
- Resolving Intune/Conditional Access confusion
- Accurate device inventory reporting

### Key Parameters
```powershell
-MinimumDaysOld 30        # Optional: only delete if older than X days
-Delete                   # Actually delete (vs. report only)
-Force                    # Skip confirmation
```

### Example Use Cases
```powershell
# Find duplicate registrations
.\delete-duplicate-device.ps1

# Remove duplicates older than 30 days
.\delete-duplicate-device.ps1 -Delete -MinimumDaysOld 30

# Remove all duplicates with confirmation
.\delete-duplicate-device.ps1 -Delete
```

---

## Side-by-Side Comparison

| Feature | Inactive Cleanup | Duplicate Cleanup |
|---------|-----------------|-------------------|
| **Primary Goal** | Remove old/unused devices | Remove duplicate registrations |
| **Deletion Criteria** | Last sign-in date | Device name + trust type |
| **What's Deleted** | Any device type if inactive | Only "Registered" duplicates |
| **What's Kept** | Recently active devices | "Hybrid joined" versions |
| **Age Filter** | Required (DaysInactive) | Optional (MinimumDaysOld) |
| **Typical Frequency** | Quarterly or monthly | As needed or monthly |
| **Risk Level** | Higher (deletes active mgmt) | Lower (only duplicates) |
| **User Impact** | Can affect current users | Minimal (keeps preferred version) |

---

## When to Use Each Script

### Use Inactive Device Cleanup When:
- ✅ You want to remove devices that haven't been used in months
- ✅ Cleaning up after employee departures
- ✅ Reducing Intune/licensing costs
- ✅ Improving security posture (fewer orphaned devices)
- ✅ Regular housekeeping (quarterly/monthly)

### Use Duplicate Device Cleanup When:
- ✅ You see duplicate device entries in Entra ID
- ✅ Devices appear twice with different trust types
- ✅ After migrating from Azure AD registered to hybrid joined
- ✅ Conditional Access policies are confusing due to duplicates
- ✅ Intune enrollment is inconsistent
- ✅ Device compliance reports are inaccurate

---

## Can I Use Both Scripts?

**YES!** They complement each other perfectly.

### Recommended Approach:

**Step 1: Remove Duplicates First**
```powershell
# Find duplicates
.\delete-duplicate-device.ps1

# Review and delete
.\delete-duplicate-device.ps1 -Delete
```

**Step 2: Then Clean Up Inactive Devices**
```powershell
# Find inactive devices
.\delete-entra-devices.ps1 -DaysInactive 180

# Review and delete
.\delete-entra-devices.ps1 -DaysInactive 180 -Delete
```

### Why This Order?
1. Removes duplicates first (smaller, safer operation)
2. Gives you cleaner data for the inactive device analysis
3. Avoids deleting both versions of a duplicate

---

## Real-World Scenarios

### Scenario 1: New Admin Taking Over
**Goal:** Clean up messy device inventory

**Steps:**
1. Run duplicate cleanup to fix registration issues
2. Run inactive cleanup (180 days) to remove old devices
3. Establish monthly schedule for both

### Scenario 2: After Azure AD Connect Implementation
**Goal:** Remove old manual registrations

**Use:** Duplicate cleanup script
- Keeps the new hybrid joined devices
- Removes old manual registrations

### Scenario 3: Quarterly Maintenance
**Goal:** Regular device hygiene

**Schedule:**
- **Week 1:** Run duplicate cleanup
- **Week 2:** Run inactive cleanup (90 days)
- **Week 3:** Review and communicate with users
- **Week 4:** Execute deletions

### Scenario 4: Former Employee Cleanup
**Goal:** Remove devices from people who left

**Use:** Inactive cleanup script
- Set DaysInactive to match your offboarding window (e.g., 60 days)
- Include disabled devices: `-IncludeDisabled`

### Scenario 5: Reducing Intune License Costs
**Goal:** Remove devices consuming licenses but not in use

**Use:** Inactive cleanup script
- Start conservative (180 days)
- Include devices that never signed in: `-IncludeNullSignIn`

---

## Safety Comparison

### Inactive Device Cleanup - Higher Risk
⚠️ **Why:** Can delete devices that are still managed/needed
- Laptops used infrequently (executives, seasonal workers)
- Backup devices not used daily
- Conference room devices with irregular use

**Mitigation:**
- Start with high day count (180+)
- Review CSV carefully
- Exclude critical device groups
- Communicate with users first

### Duplicate Device Cleanup - Lower Risk
✅ **Why:** Only removes duplicate registrations
- Keeps the preferred version (hybrid joined)
- Only affects duplicates, not unique devices
- Minimal operational impact

**Mitigation:**
- Use `-MinimumDaysOld` to avoid recent duplicates
- Still review CSV before deleting
- Test with -WhatIf first

---

## Output Files Comparison

### Inactive Device Cleanup
**Report:** `EntraDevices_Inactive_YYYYMMDD_HHMMSS.csv`

**Contains:**
- All inactive devices across all trust types
- Last sign-in date
- Days inactive
- Operating system info

**Use For:** Understanding which devices haven't been used

### Duplicate Device Cleanup
**Report:** `EntraDevices_DuplicateCleanup_YYYYMMDD_HHMMSS.csv`

**Contains:**
- Only registered devices with hybrid duplicates
- Trust type information
- How many hybrid versions exist
- Reason for deletion

**Use For:** Understanding duplicate registration patterns

---

## Permissions Needed (Both Scripts)

### For Reporting Only:
- `Device.Read.All` or `Directory.Read.All`

### For Deletion:
- `Device.ReadWrite.All`

Both scripts request the same permissions.

---

## Best Practices for Using Both

### 1. ✅ Establish a Schedule
- **Duplicates:** Monthly or as-needed
- **Inactive:** Quarterly or monthly

### 2. ✅ Always Report First
```powershell
# Month 1 - Discovery phase
.\delete-duplicate-device.ps1                     # Week 1
.\delete-entra-devices.ps1 -DaysInactive 180     # Week 2
# Review CSVs, communicate with stakeholders

# Month 2 - Action phase
.\delete-duplicate-device.ps1 -Delete            # Week 1
.\delete-entra-devices.ps1 -DaysInactive 180 -Delete  # Week 2
```

### 3. ✅ Keep Audit Logs
- Save all CSV reports
- Keep deletion logs
- Document decisions

### 4. ✅ Communicate Changes
- Notify IT team before running
- Inform users about device cleanup policies
- Set expectations for device registration

### 5. ✅ Test in Non-Production First
If you have a test/dev tenant, run there first.

### 6. ✅ Start Conservative
- Use high day counts initially
- Use age filters on duplicate cleanup
- Gradually tighten criteria

---

## Summary Table

| Aspect | Inactive Cleanup | Duplicate Cleanup |
|--------|-----------------|-------------------|
| **Frequency** | Monthly/Quarterly | As-needed/Monthly |
| **Risk** | Medium-High | Low-Medium |
| **Scope** | All device types | Registered only |
| **User Impact** | Potential | Minimal |
| **Data Quality** | Removes stale data | Fixes duplicate data |
| **Prerequisites** | None | None |
| **Can run together?** | Yes (duplicates first) | Yes |

---

## Quick Decision Tree

```
Do you have devices with the same name but different trust types?
├─ YES → Use Duplicate Device Cleanup
└─ NO → Continue

Do you have devices that haven't been used in 90+ days?
├─ YES → Use Inactive Device Cleanup
└─ NO → You're all set!

Both problems exist?
└─ Run Duplicate Cleanup first, then Inactive Cleanup
```

---

## Getting Help

Both scripts support:
- `-WhatIf` parameter for safe testing
- Detailed CSV reports
- Error logging
- Comprehensive help via `Get-Help .\script-name.ps1 -Full`

---

**Remember:** These scripts are tools to help maintain a clean Entra ID environment. Always review reports before deleting, test with `-WhatIf`, and communicate with your team!
