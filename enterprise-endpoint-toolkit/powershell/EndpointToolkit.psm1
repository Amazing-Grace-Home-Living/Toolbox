#requires -Version 7.0
Set-StrictMode -Version Latest

function Get-EndpointField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Device,
        [Parameter(Mandatory)][string[]]$Names
    )
    foreach ($key in $Names) {
        $value = $null
        if ($Device -is [System.Collections.IDictionary]) {
            if ($Device.Contains($key)) { $value = $Device[$key] }
        } else {
            $property = $Device.PSObject.Properties[$key]
            if ($null -ne $property) { $value = $property.Value }
        }
        if ($null -ne $value -and (-not ($value -is [string]) -or -not [string]::IsNullOrWhiteSpace($value))) {
            return $value
        }
    }
    return $null
}

function Get-EndpointComplianceAudit {
    <#
    .SYNOPSIS
    Read-only classification of Intune / Workspace ONE / sample inventory records.
    .DESCRIPTION
    Never guesses that missing compliance or check-in values are healthy. No
    device updates, network requests, credentials, or administrative privileges.
    .EXAMPLE
    [pscustomobject]@{ deviceName='LAB-01'; complianceState='noncompliant' } |
        Get-EndpointComplianceAudit
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$Device,
        [ValidateRange(1, 3650)]
        [int]$StaleDays = 30,
        [datetimeoffset]$Now = [datetimeoffset]::UtcNow
    )
    process {
        $current = $Now.ToUniversalTime()
        $name = Get-EndpointField -Device $Device -Names @('deviceName', 'DeviceFriendlyName', 'FriendlyName', 'name')
        $id = Get-EndpointField -Device $Device -Names @('id', 'Id', 'DeviceId', 'deviceId')
        $platform = Get-EndpointField -Device $Device -Names @('operatingSystem', 'Platform', 'platform', 'OS')
        $status = Get-EndpointField -Device $Device -Names @('complianceState', 'ComplianceStatus', 'complianceStatus')
        $state = if ($null -eq $status) { 'unknown' } else { ([string]$status).ToLowerInvariant() }
        if ($state -notin @('compliant', 'noncompliant')) { $state = 'unknown' }

        $sync = Get-EndpointField -Device $Device -Names @('lastSyncDateTime', 'LastSeen', 'lastSeen', 'LastSyncDateTime')
        $parsed = [datetimeoffset]::MinValue
        $validSync = $false
        if ($sync -is [datetimeoffset]) {
            $parsed = $sync
            $validSync = $true
        } elseif ($sync -is [datetime]) {
            # PowerShell ConvertFrom-Json often auto-parses ISO timestamps to DateTime.
            # Reject timestamps without timezone information rather than guessing.
            if ($sync.Kind -ne [System.DateTimeKind]::Unspecified) {
                $parsed = [datetimeoffset]$sync
                $validSync = $true
            }
        } elseif ($sync -is [string] -and ($sync.EndsWith('Z') -or $sync.EndsWith('z') -or $sync -match '[+-]\d{2}:\d{2}')) {
            $validSync = [datetimeoffset]::TryParse(
                $sync,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None,
                [ref]$parsed
            )
        }
        $utcSync = if ($validSync) { $parsed.ToUniversalTime() } else { $null }
        $freshness = if (-not $validSync -or $utcSync -gt $current.AddDays(1)) {
            'unknown'
        } elseif (($current - $utcSync).TotalDays -gt $StaleDays) {
            'stale'
        } else {
            'recent'
        }
        $risk = if ($state -eq 'noncompliant') {
            'high'
        } elseif ($freshness -eq 'stale') {
            'medium'
        } elseif ($state -eq 'unknown' -or $freshness -eq 'unknown') {
            'unknown'
        } else {
            'low'
        }

        [pscustomobject]@{
            Id         = if ($null -eq $id) { '' } else { [string]$id }
            Name       = if ($null -eq $name) { 'Unnamed' } else { [string]$name }
            Platform   = if ($null -eq $platform) { 'Unknown' } else { [string]$platform }
            Compliance = $state
            Freshness  = $freshness
            LastSync   = if ($null -eq $utcSync) { $null } else { $utcSync.ToString('o') }
            Risk       = $risk
        }
    }
}

Export-ModuleMember -Function Get-EndpointComplianceAudit
