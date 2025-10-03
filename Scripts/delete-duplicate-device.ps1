<# 
.SYNOPSIS
  Remove duplicate Entra ID devices - keeps Hybrid joined, removes Registered duplicates.

.DESCRIPTION
  This script identifies devices that exist in Entra ID with multiple registrations:
  - Looks for devices with the same DisplayName
  - Identifies cases where both "Azure AD registered" and "Azure AD hybrid joined" trust types exist
  - Keeps the Hybrid joined device (preferred for domain-joined machines)
  - Removes the Registered device(s) to eliminate duplicates
  - Exports a report of actions taken
  - Safe by default with confirmation prompts

.PARAMETER ReportPath
  Path to write the CSV report. Default: .\EntraDevices_DuplicateCleanup_<timestamp>.csv

.PARAMETER Delete
  Actually delete duplicate registered devices from Entra ID (with confirmation unless -Force is used)

.PARAMETER Force
  Skip confirmation prompts for deletion (use with caution!)

.PARAMETER NoBrowser
  Use device code flow for authentication (helpful on servers without browser)

.PARAMETER MinimumDaysOld
  Only consider registered devices for deletion if they are at least this many days old (safety measure).
  Default: 0 (no age restriction)

.EXAMPLE
  .\delete-duplicate-device.ps1
  
  Generates a report of duplicate devices without deleting anything.

.EXAMPLE
  .\delete-duplicate-device.ps1 -Delete
  
  Finds and deletes registered duplicates (with confirmation).

.EXAMPLE
  .\delete-duplicate-device.ps1 -Delete -Force
  
  Deletes duplicate registered devices without confirmation (USE WITH CAUTION!).

.EXAMPLE
  .\delete-duplicate-device.ps1 -MinimumDaysOld 30 -Delete
  
  Only deletes registered devices that are at least 30 days old.

.EXAMPLE
  .\delete-duplicate-device.ps1 -Delete -WhatIf
  
  Shows what would be deleted without actually deleting (WhatIf preview).

.REQUIREMENTS
  - PowerShell 7+ recommended (Windows PowerShell 5.1+ works too)
  - Microsoft Graph PowerShell SDK:
      Install-Module Microsoft.Graph -Scope CurrentUser
  - Graph permissions (consent on first run):
      Read/report only:    Device.Read.All or Directory.Read.All
      Deletion:            Device.ReadWrite.All

.NOTES
  Author: Entra ID Device Management
  Version: 1.0
  Last Updated: October 3, 2025
  
  Trust Types:
  - "Azure AD registered" = Personal devices, BYOD, or duplicate registrations
  - "Azure AD joined" = Cloud-only joined devices
  - "Azure AD hybrid joined" = On-premises AD synced devices (typically preferred)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(HelpMessage="Path to write the CSV report. Default: .\EntraDevices_DuplicateCleanup_<timestamp>.csv")]
  [ValidateScript({
    $dir = Split-Path $_ -Parent
    if ($dir -and -not (Test-Path $dir)) {
      throw "Directory does not exist: $dir"
    }
    $true
  })]
  [string]$ReportPath,

  [switch]$Delete,               # Actually delete duplicate devices from Entra ID
  [switch]$Force,                # Skip confirmation prompts for deletion
  [switch]$NoBrowser,            # Use device code flow (helpful on servers)
  
  [Parameter(HelpMessage="Only delete registered devices older than this many days (safety measure)")]
  [ValidateRange(0, 36500)]
  [int]$MinimumDaysOld = 0
)

# Validate parameter combinations
if ($Force -and -not $Delete) {
  Write-Warning "The -Force switch has no effect without -Delete. Ignoring -Force."
}

function Connect-GraphSafe {
  $scopes = @("Device.Read.All")
  if ($Delete) { $scopes += "Device.ReadWrite.All" }

  Write-Host "Connecting to Microsoft Graph with scopes: $($scopes -join ', ')" -ForegroundColor Cyan
  $connectParams = @{
    Scopes = $scopes
  }
  if ($NoBrowser) {
    $connectParams["UseDeviceCode"] = $true
  }

  try {
    Connect-MgGraph @connectParams | Out-Null
    $prof = Get-MgContext
    Write-Host "Connected. TenantId: $($prof.TenantId) - Account: $($prof.Account)" -ForegroundColor Green
  }
  catch {
    throw "Failed to connect to Microsoft Graph. $($_.Exception.Message)"
  }
}

function Get-AllDevices {
  Write-Host "`nFetching all devices from Entra ID (this may take a moment)..." -ForegroundColor Cyan

  # Request specific properties to reduce payload
  $props = @(
    "id",
    "displayName",
    "deviceId",
    "operatingSystem",
    "operatingSystemVersion",
    "trustType",
    "deviceOwnership",
    "accountEnabled",
    "approximateLastSignInDateTime",
    "registrationDateTime",
    "createdDateTime"
  ) -join ","

  try {
    $devices = Get-MgDevice -All -Property $props -ErrorAction Stop
    Write-Host "Retrieved $($devices.Count) total devices from Entra ID." -ForegroundColor Cyan
  }
  catch {
    throw "Failed to retrieve devices from Microsoft Graph: $($_.Exception.Message)"
  }

  if (-not $devices -or $devices.Count -eq 0) {
    Write-Warning "No devices found in the tenant."
    return @()
  }

  return $devices
}

function Find-DuplicateDevices {
  param(
    [array]$Devices,
    [int]$MinimumDaysOld
  )

  Write-Host "`nAnalyzing devices for duplicates..." -ForegroundColor Cyan

  # Group devices by DisplayName
  $grouped = $Devices | Group-Object -Property DisplayName

  # Find groups with multiple devices
  $duplicateGroups = $grouped | Where-Object { $_.Count -gt 1 }
  
  Write-Host "Found $($duplicateGroups.Count) device names with multiple registrations." -ForegroundColor Cyan

  $toDelete = @()
  $groupsProcessed = 0

  foreach ($group in $duplicateGroups) {
    $groupsProcessed++
    $devicesInGroup = $group.Group
    
    # Check if there's at least one Hybrid joined and one Registered device
    $hybridDevices = $devicesInGroup | Where-Object { $_.TrustType -eq "ServerAd" }
    $registeredDevices = $devicesInGroup | Where-Object { $_.TrustType -eq "Workplace" }
    
    if ($hybridDevices.Count -gt 0 -and $registeredDevices.Count -gt 0) {
      # We have the scenario: Hybrid joined + Registered duplicates
      Write-Host "  [$groupsProcessed] '$($group.Name)' - Found $($hybridDevices.Count) Hybrid + $($registeredDevices.Count) Registered" -ForegroundColor Yellow
      
      foreach ($regDevice in $registeredDevices) {
        # Calculate age
        $ageInDays = $null
        if ($regDevice.RegistrationDateTime) {
          $ageInDays = [math]::Round(((Get-Date).ToUniversalTime() - $regDevice.RegistrationDateTime.ToUniversalTime()).TotalDays, 1)
        }
        
        # Apply age filter if specified
        if ($MinimumDaysOld -gt 0) {
          if ($null -eq $ageInDays -or $ageInDays -lt $MinimumDaysOld) {
            Write-Host "    Skipping (too new): $($regDevice.DisplayName) - Age: $ageInDays days" -ForegroundColor Gray
            continue
          }
        }
        
        # Parse last sign-in
        $lastSignIn = $null
        if ($regDevice.ApproximateLastSignInDateTime) {
          $lastSignIn = $regDevice.ApproximateLastSignInDateTime
        }
        elseif ($regDevice.AdditionalProperties.ContainsKey("approximateLastSignInDateTime")) {
          $raw = $regDevice.AdditionalProperties["approximateLastSignInDateTime"]
          if ($raw) {
            try { $lastSignIn = [DateTime]::Parse($raw) } catch { }
          }
        }
        
        # Add to deletion list
        $toDelete += [pscustomobject]@{
          ObjectId                        = $regDevice.Id
          DeviceId                        = $regDevice.DeviceId
          DisplayName                     = $regDevice.DisplayName
          OperatingSystem                 = $regDevice.OperatingSystem
          OperatingSystemVersion          = $regDevice.OperatingSystemVersion
          TrustType                       = $regDevice.TrustType
          TrustTypeFriendly               = "Azure AD registered"
          DeviceOwnership                 = $regDevice.DeviceOwnership
          AccountEnabled                  = $regDevice.AccountEnabled
          RegistrationDateTimeUtc         = $regDevice.RegistrationDateTime
          CreatedDateTimeUtc              = $regDevice.CreatedDateTime
          ApproximateLastSignInDateTimeUtc= $lastSignIn
          AgeInDays                       = $ageInDays
          Reason                          = "Duplicate - Hybrid joined version exists"
          HybridDeviceCount               = $hybridDevices.Count
        }
      }
    }
  }

  Write-Host "`nIdentified $($toDelete.Count) registered device(s) to remove (duplicates of hybrid joined devices)." -ForegroundColor Yellow

  return $toDelete
}

function Write-Report {
  param(
    [array]$Rows,
    [string]$Path
  )
  
  if (-not $Rows -or $Rows.Count -eq 0) {
    Write-Host "No duplicate devices to report." -ForegroundColor Green
    return $null
  }
  
  if (-not $Path) {
    $stamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $Path  = ".\EntraDevices_DuplicateCleanup_${stamp}.csv"
  }
  
  try {
    $Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "`nReport written: $Path ($($Rows.Count) devices)" -ForegroundColor Green
    
    # Show absolute path for clarity
    $fullPath = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path
    if ($fullPath) {
      Write-Host "Full path: $fullPath" -ForegroundColor Gray
    }
  }
  catch {
    Write-Error "Failed to write report to $Path : $($_.Exception.Message)"
    throw
  }
  
  return $Path
}

function Remove-DuplicateDevices {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [array]$Rows,
    [switch]$Force
  )
  
  if (-not $Rows -or $Rows.Count -eq 0) {
    Write-Warning "No devices supplied for deletion."
    return
  }

  Write-Host "`n" + ("=" * 80) -ForegroundColor Yellow
  Write-Host "DELETION WARNING" -ForegroundColor Red
  Write-Host ("=" * 80) -ForegroundColor Yellow
  Write-Host "You are about to DELETE $($Rows.Count) registered device(s) from Entra ID." -ForegroundColor Yellow
  Write-Host "These are duplicate registrations - the hybrid joined versions will be kept." -ForegroundColor Yellow
  Write-Host "This action cannot be undone!" -ForegroundColor Red
  Write-Host ("=" * 80) -ForegroundColor Yellow
  
  if (-not $Force) {
    Write-Host "`nDevices to be deleted (registered duplicates):" -ForegroundColor Yellow
    $Rows | Select-Object -First 10 DisplayName, TrustTypeFriendly, OperatingSystem, AgeInDays, AccountEnabled | 
      Format-Table -AutoSize
    
    if ($Rows.Count -gt 10) {
      Write-Host "... and $($Rows.Count - 10) more device(s). See the CSV report for full list." -ForegroundColor Gray
    }
    
    Write-Host ""
    $ans = Read-Host "Type 'DELETE' (all caps) to proceed, or anything else to cancel"
    if ($ans -ne 'DELETE') {
      Write-Host "Aborted by user." -ForegroundColor Cyan
      return
    }
  }

  Write-Host "`nDeleting duplicate registered devices..." -ForegroundColor Yellow
  $errors = @()
  $succeeded = 0
  $i = 0
  
  foreach ($row in $Rows) {
    $i++
    $id = $row.ObjectId
    if (-not $id) { 
      $errors += "Row $i missing ObjectId"
      continue 
    }

    try {
      # Protect with ShouldProcess; also allows -WhatIf
      if ($PSCmdlet.ShouldProcess("$($row.DisplayName) ($($row.TrustTypeFriendly)) - $id", "Remove-MgDevice")) {
        Remove-MgDevice -DeviceId $id -ErrorAction Stop
        $succeeded++
        Write-Host "[$i/$($Rows.Count)] ✓ Deleted: $($row.DisplayName) ($($row.TrustTypeFriendly))" -ForegroundColor Green
      }
    }
    catch {
      $msg = "[$i/$($Rows.Count)] ✗ FAILED: $($row.DisplayName) - $($_.Exception.Message)"
      Write-Warning $msg
      $errors += $msg
    }
    
    # Progress indicator for large batches
    if ($i % 10 -eq 0 -and $i -lt $Rows.Count) {
      Write-Host "Progress: $i/$($Rows.Count) processed..." -ForegroundColor Gray
    }
  }

  Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
  Write-Host "DELETION SUMMARY" -ForegroundColor Cyan
  Write-Host ("=" * 80) -ForegroundColor Cyan
  Write-Host "  Successfully deleted: $succeeded" -ForegroundColor Green
  Write-Host "  Failed: $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { "Red" } else { "Gray" })
  Write-Host ("=" * 80) -ForegroundColor Cyan

  if ($errors.Count -gt 0) {
    $stamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $log = ".\EntraDevices_DuplicateDeleteErrors_${stamp}.log"
    $errors | Out-File -FilePath $log -Encoding UTF8
    Write-Warning "Some deletions failed. See error log: $log"
  }
}

# -------------------------
# Main execution flow
# -------------------------
try {
  Write-Host "=" * 80 -ForegroundColor Cyan
  Write-Host "Entra ID Duplicate Device Cleanup Script" -ForegroundColor Cyan
  Write-Host "=" * 80 -ForegroundColor Cyan
  Write-Host "Purpose: Remove 'Registered' devices when 'Hybrid joined' version exists" -ForegroundColor Cyan
  Write-Host "=" * 80 -ForegroundColor Cyan
  
  Connect-GraphSafe

  # Get all devices
  $allDevices = Get-AllDevices
  
  if ($allDevices.Count -eq 0) {
    Write-Host "`nNo devices found. Exiting." -ForegroundColor Green
    exit 0
  }

  # Find duplicates
  $duplicates = Find-DuplicateDevices -Devices $allDevices -MinimumDaysOld $MinimumDaysOld

  if ($duplicates.Count -eq 0) {
    Write-Host "`nNo duplicate devices found. Nothing to delete." -ForegroundColor Green
    Write-Host "Your Entra ID is clean - no registered duplicates of hybrid joined devices exist." -ForegroundColor Green
  }
  else {
    # Display summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Total devices in tenant: $($allDevices.Count)" -ForegroundColor Cyan
    Write-Host "  Duplicate registered devices found: $($duplicates.Count)" -ForegroundColor Yellow
    
    if ($MinimumDaysOld -gt 0) {
      Write-Host "  Age filter applied: Only devices $MinimumDaysOld+ days old" -ForegroundColor Gray
    }
    
    # Write the report
    $reportPath = Write-Report -Rows $duplicates -Path $ReportPath
    
    if ($Delete) {
      Write-Host "`nProceeding with deletion..." -ForegroundColor Yellow
      Remove-DuplicateDevices -Rows $duplicates -Force:$Force
    }
    else {
      Write-Host "`nNo devices were deleted (report-only mode)." -ForegroundColor Cyan
      Write-Host "Review the report at: $reportPath" -ForegroundColor Cyan
      Write-Host "To delete these duplicate devices, re-run with the -Delete switch." -ForegroundColor Cyan
    }
  }
}
catch {
  Write-Error "Script execution failed: $($_.Exception.Message)"
  Write-Error $_.ScriptStackTrace
  exit 1
}
finally {
  # Clean disconnect
  try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-Host "`nDisconnected from Microsoft Graph." -ForegroundColor Gray
  }
  catch {
    # Silently ignore disconnect errors
  }
}

Write-Host "`nScript completed." -ForegroundColor Green
