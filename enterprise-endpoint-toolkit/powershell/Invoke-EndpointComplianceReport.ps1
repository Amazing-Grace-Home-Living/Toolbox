#requires -Version 7.0
<#
.SYNOPSIS
Produce read-only compliance reports from an exported Intune / Workspace ONE inventory.
.DESCRIPTION
Accepts a JSON array or object with value/Devices/devices. Writes JSON and
CSV locally, with no API calls, privileged actions, or credentials.
.EXAMPLE
./Invoke-EndpointComplianceReport.ps1 -OutDirectory ./reports
.EXAMPLE
./Invoke-EndpointComplianceReport.ps1 -InputPath ../examples/devices.json -StaleDays 14
#>
[CmdletBinding()]
param(
    [string]$InputPath = (Join-Path $PSScriptRoot '../examples/devices.json'),
    [string]$OutDirectory = (Join-Path $PSScriptRoot '../reports'),
    [ValidateRange(1, 3650)][int]$StaleDays = 30,
    [datetimeoffset]$Now = [datetimeoffset]::UtcNow
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'EndpointToolkit.psm1') -Force -ErrorAction Stop

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Input file does not exist: $InputPath"
}
$document = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $InputPath -Raw -Encoding utf8) -Depth 50 -NoEnumerate
if ($document -is [array]) {
    $devices = $document
} elseif ($null -ne $document -and $document -is [psobject]) {
    $devices = $null
    foreach ($name in @('value', 'Devices', 'devices')) {
        $property = $document.PSObject.Properties[$name]
        if ($null -ne $property) { $devices = $property.Value; break }
    }
} else {
    $devices = $null
}
if ($null -eq $devices -or $devices -isnot [array]) {
    throw 'Expected a JSON array or object with an array named value, Devices, or devices'
}

$rows = @(
    foreach ($device in $devices) {
        if ($null -eq $device -or $device -isnot [psobject] -or $device -is [string] -or $device -is [array]) {
            throw 'Every inventory record must be a JSON object'
        }
        Get-EndpointComplianceAudit -Device $device -StaleDays $StaleDays -Now $Now
    }
)
$summary = [ordered]@{
    total        = $rows.Count
    high         = @($rows | Where-Object Risk -EQ 'high').Count
    medium       = @($rows | Where-Object Risk -EQ 'medium').Count
    unknown      = @($rows | Where-Object Risk -EQ 'unknown').Count
    low          = @($rows | Where-Object Risk -EQ 'low').Count
    noncompliant = @($rows | Where-Object Compliance -EQ 'noncompliant').Count
    stale        = @($rows | Where-Object Freshness -EQ 'stale').Count
}
New-Item -ItemType Directory -Path $OutDirectory -Force | Out-Null
$jsonPath = Join-Path $OutDirectory 'report.json'
$csvPath = Join-Path $OutDirectory 'inventory.csv'
$report = [ordered]@{
    source = [System.IO.Path]::GetFileName($InputPath)
    created_at = $Now.ToUniversalTime().ToString('o')
    summary = $summary
    devices = $rows
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding utf8

# CSV is for human review. Prefix spreadsheet formulas in untrusted device names
# to prevent evaluation when opened in Excel or similar spreadsheet programs.
$safeRows = @(
    foreach ($row in $rows) {
        $clean = [ordered]@{}
        foreach ($field in @('Id', 'Name', 'Platform', 'Compliance', 'Freshness', 'LastSync', 'Risk')) {
            $value = [string]$row.$field
            if ($value -match '^[=+\-@\t\r\n]') { $value = "'" + $value }
            $clean[$field] = $value
        }
        [pscustomobject]$clean
    }
)
if ($safeRows.Count -eq 0) {
    'Id,Name,Platform,Compliance,Freshness,LastSync,Risk' | Set-Content -LiteralPath $csvPath -Encoding utf8
} else {
    $safeRows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
}
Write-Output "Audited $($summary.total) devices; high=$($summary.high), stale=$($summary.stale), unknown=$($summary.unknown)"
Write-Output "JSON: $jsonPath"
Write-Output "CSV:  $csvPath"
