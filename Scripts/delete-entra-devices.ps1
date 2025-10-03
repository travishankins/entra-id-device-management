<# 
.SYNOPSIS
Entra ID (Azure AD) device cleanup helper: report and optional delete.

.DESCRIPTION
- Queries Microsoft Graph for devices and their approximateLastSignInDateTime
- Filters devices inactive for a specified number of days (or never signed in)
- Exports a CSV report
- Optionally deletes those devices (only with -Delete)
- Safe by default (interactive confirmation; use -Force to suppress)

.PARAMETER DaysInactive
Devices with no sign-in or last sign-in older than this many days will be selected.

.PARAMETER ReportPath
Path to write the CSV report. Default: .\EntraDevices_Inactive_<timestamp>.csv

.PARAMETER IncludeDisabled
Include accountEnabled:$false devices in the results

.PARAMETER Delete
Actually delete devices from Entra ID (with confirmation unless -Force is used)

.PARAMETER Force
Skip confirmation prompts for deletion (use with caution!)

.PARAMETER IncludeNullSignIn
Include devices that have never signed in (null approximateLastSignInDateTime)

.PARAMETER NoBrowser
Use device code flow for authentication (helpful on servers without browser)

.EXAMPLE
.\delete-entra-devices.ps1 -DaysInactive 90

Generates a report of devices inactive for 90+ days.

.EXAMPLE
.\delete-entra-devices.ps1 -DaysInactive 180 -IncludeNullSignIn -Delete

Finds and deletes devices inactive for 180+ days or never signed in (with confirmation).

.EXAMPLE
.\delete-entra-devices.ps1 -DaysInactive 365 -Delete -Force -WhatIf

Shows what would be deleted without actually deleting (WhatIf preview).

.REQUIREMENTS
- PowerShell 7+ recommended (Windows PowerShell 5.1+ works too)
- Microsoft Graph PowerShell SDK:
    Install-Module Microsoft.Graph -Scope CurrentUser
- Graph permissions (consent on first run):
    Read/report only:    Device.Read.All or Directory.Read.All
    Deletion:            Device.ReadWrite.All

.NOTES
Author: Travis Hankins
Version: 2.0
Last Updated: October 3, 2025
#>

[CmdletBinding(SupportsShouldProcess)]
param(
[Parameter(Mandatory=$true, HelpMessage="Devices with no sign-in or last sign-in older than this many days will be selected.")]
[ValidateRange(1, 36500)]
[int]$DaysInactive,

[Parameter(HelpMessage="Path to write the CSV report. Default: .\EntraDevices_Inactive_<timestamp>.csv")]
[ValidateScript({
$dir = Split-Path $_ -Parent
if ($dir -and -not (Test-Path $dir)) {
    throw "Directory does not exist: $dir"
}
$true
})]
[string]$ReportPath,

[switch]$IncludeDisabled,      # Include accountEnabled:$false devices in the results
[switch]$Delete,               # Actually delete devices from Entra ID (with confirmation)
[switch]$Force,                # Skip confirmation prompts for deletion
[switch]$IncludeNullSignIn,    # Include devices that have never signed in (null approximateLastSignInDateTime)
[switch]$NoBrowser             # Use device code flow (helpful on servers)
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

function Get-InactiveDevices {
param(
[int]$DaysInactive,
[switch]$IncludeDisabled,
[switch]$IncludeNullSignIn
)

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$DaysInactive)

# Ask Graph for specific properties (reduces payload).
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

Write-Host "Fetching devices from Graph (this may take a moment)..." -ForegroundColor Cyan

# Pull all devices. (Server-side filter on approximateLastSignInDateTime is limited; filter client-side robustly.)
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

if (-not $IncludeDisabled) {
$beforeCount = $devices.Count
$devices = $devices | Where-Object { $_.AccountEnabled -ne $false }
Write-Host "Filtered out $($beforeCount - $devices.Count) disabled devices." -ForegroundColor Gray
}

# Build a computed set with last sign-in and inactivity days
$computed = $devices | ForEach-Object {
$last = $null

# Try to get approximateLastSignInDateTime from multiple possible locations
if ($_.ApproximateLastSignInDateTime) {
    $last = $_.ApproximateLastSignInDateTime
}
elseif ($_.AdditionalProperties.ContainsKey("approximateLastSignInDateTime")) {
    $raw = $_.AdditionalProperties["approximateLastSignInDateTime"]
    if ($raw) { 
        try {
            $last = [DateTime]::Parse($raw)
        }
        catch {
            # If parse fails, leave as null
        }
    }
}

[pscustomobject]@{
    ObjectId                        = $_.Id
    DeviceId                        = $_.DeviceId
    DisplayName                     = $_.DisplayName
    OperatingSystem                 = $_.OperatingSystem
    OperatingSystemVersion          = $_.OperatingSystemVersion
    TrustType                       = $_.TrustType
    DeviceOwnership                 = $_.DeviceOwnership
    AccountEnabled                  = $_.AccountEnabled
    RegistrationDateTimeUtc         = $_.RegistrationDateTime
    CreatedDateTimeUtc              = $_.CreatedDateTime
    ApproximateLastSignInDateTimeUtc= $last
    InactiveDays                    = if ($last) { [math]::Round(((Get-Date).ToUniversalTime() - $last.ToUniversalTime()).TotalDays, 1) } else { $null }
    NeverSignedIn                   = if ($null -eq $last) { $true } else { $false }
}
}

# Filter by inactivity
$inactive = $computed | Where-Object {
if ($_.NeverSignedIn) {
    $IncludeNullSignIn.IsPresent
} else {
    # last sign-in exists and is older than cutoff
    $_.ApproximateLastSignInDateTimeUtc -lt $cutoff
}
}
Write-Host "Found $($inactive.Count) device(s) matching inactivity criteria." -ForegroundColor Cyan
if ($IncludeNullSignIn) {
    $neverCount = ($inactive | Where-Object { $_.NeverSignedIn }).Count
    Write-Host "  - Never signed in: $neverCount" -ForegroundColor Gray
}
return $inactive | Sort-Object -Property @{Expression='NeverSignedIn';Descending=$true}, @{Expression='InactiveDays';Descending=$true}, 'DisplayName'
}

function Write-Report {
param(
[array]$Rows,
[string]$Path
)
if (-not $Path) {
$stamp = (Get-Date -Format "yyyyMMdd_HHmmss")
$Path  = ".\EntraDevices_Inactive_${stamp}.csv"
}

try {
$Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
Write-Host "Report written: $Path ($($Rows.Count) devices)" -ForegroundColor Green

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

function Remove-Devices {
[CmdletBinding(SupportsShouldProcess=$true)]
param(
[array]$Rows,
[switch]$Force
)
if (-not $Rows -or $Rows.Count -eq 0) {
Write-Warning "No devices supplied for removal."
return
}

Write-Host "`nYou are about to DELETE $($Rows.Count) device(s) from Entra ID." -ForegroundColor Yellow
Write-Host "This action cannot be undone!" -ForegroundColor Red

if (-not $Force) {
Write-Host "`nDevices to be deleted:" -ForegroundColor Yellow
$Rows | Select-Object -First 10 DisplayName, OperatingSystem, InactiveDays, NeverSignedIn | Format-Table -AutoSize
if ($Rows.Count -gt 10) {
    Write-Host "... and $($Rows.Count - 10) more device(s). See the CSV for full list." -ForegroundColor Gray
}

$ans = Read-Host "`nType 'DELETE' (all caps) to proceed"
if ($ans -ne 'DELETE') {
    Write-Host "Aborted by user." -ForegroundColor Cyan
    return
}
}

Write-Host "`nDeleting devices..." -ForegroundColor Yellow
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
    # Protect with ShouldProcess; also allows -WhatIf on the main script call
    if ($PSCmdlet.ShouldProcess("$($row.DisplayName) ($id)", "Remove-MgDevice")) {
    Remove-MgDevice -DeviceId $id -ErrorAction Stop
    $succeeded++
    Write-Host "[$i/$($Rows.Count)] ✓ Deleted: $($row.DisplayName)" -ForegroundColor Green
    }
}
catch {
    $msg = "[$i/$($Rows.Count)] ✗ FAILED: $($row.DisplayName) ($id) - $($_.Exception.Message)"
    Write-Warning $msg
    $errors += $msg
}

# Progress indicator for large batches
if ($i % 10 -eq 0) {
    Write-Host "Progress: $i/$($Rows.Count) processed..." -ForegroundColor Gray
}
}

Write-Host "`nDeletion Summary:" -ForegroundColor Cyan
Write-Host "  Successfully deleted: $succeeded" -ForegroundColor Green
Write-Host "  Failed: $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { "Red" } else { "Gray" })

if ($errors.Count -gt 0) {
$stamp = (Get-Date -Format "yyyyMMdd_HHmmss")
$log = ".\EntraDevices_DeleteErrors_${stamp}.log"
$errors | Out-File -FilePath $log -Encoding UTF8
Write-Warning "Some deletions failed. See error log: $log"
}
}

# -------------------------
# Main execution flow
# -------------------------
try {
Connect-GraphSafe

Write-Host "Cutoff: devices inactive (or never signed in, if selected) for >= $DaysInactive day(s)." -ForegroundColor Cyan
$inactive = Get-InactiveDevices -DaysInactive $DaysInactive -IncludeDisabled:$IncludeDisabled -IncludeNullSignIn:$IncludeNullSignIn

if ($inactive.Count -eq 0) {
Write-Host "No inactive devices found matching criteria." -ForegroundColor Green
}
else {
Write-Host "Found $($inactive.Count) inactive device(s)." -ForegroundColor Yellow

# Display summary statistics
$neverSignedIn = ($inactive | Where-Object { $_.NeverSignedIn }).Count
$disabled = ($inactive | Where-Object { $_.AccountEnabled -eq $false }).Count

Write-Host "  - Never signed in: $neverSignedIn" -ForegroundColor Cyan
Write-Host "  - Disabled accounts: $disabled" -ForegroundColor Cyan

# Write the report
$reportPath = Write-Report -Rows $inactive -Path $ReportPath

if ($Delete) {
    Write-Host "`nProceeding with deletion..." -ForegroundColor Yellow
    Remove-Devices -Rows $inactive -Force:$Force
}
else {
    Write-Host "`nNo devices were deleted. Review the report at: $reportPath" -ForegroundColor Cyan
    Write-Host "To delete these devices, re-run with the -Delete switch." -ForegroundColor Cyan
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

Write-Host "`nScript completed." -ForegroundColor Green.