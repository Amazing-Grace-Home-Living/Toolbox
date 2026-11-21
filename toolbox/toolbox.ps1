#requires -Version 7.0
<#
.SYNOPSIS
Convenient entry point for the read-only endpoint compliance report.
.EXAMPLE
pwsh -File ./toolbox/toolbox.ps1 -OutDirectory ./reports
.EXAMPLE
pwsh -File ./toolbox/toolbox.ps1 -InputPath ./enterprise-endpoint-toolkit/examples/devices.json
#>
[CmdletBinding()]
param(
    [string]$InputPath = (Join-Path $PSScriptRoot '../enterprise-endpoint-toolkit/examples/devices.json'),
    [string]$OutDirectory = (Join-Path $PSScriptRoot '../enterprise-endpoint-toolkit/reports'),
    [ValidateRange(1,3650)][int]$StaleDays = 30
)
& (Join-Path $PSScriptRoot '../enterprise-endpoint-toolkit/powershell/Invoke-EndpointComplianceReport.ps1') @PSBoundParameters
