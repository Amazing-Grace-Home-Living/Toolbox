BeforeAll {
    Import-Module "$PSScriptRoot/../powershell/EndpointToolkit.psm1" -Force
}

Describe 'Get-EndpointComplianceAudit' {
    It 'marks missing compliance and check-in values unknown, not compliant' {
        $result = [pscustomobject]@{ deviceName = 'LAB-01' } | Get-EndpointComplianceAudit
        $result.Risk | Should -Be 'unknown'
        $result.Freshness | Should -Be 'unknown'
    }

    It 'flags explicit non-compliance as high even with missing timestamp' {
        $result = [pscustomobject]@{ deviceName = 'LAB-02'; complianceState = 'noncompliant' } | Get-EndpointComplianceAudit
        $result.Risk | Should -Be 'high'
    }

    It 'accepts recent Intune inventory with timezone and platform fields' {
        $now = [datetimeoffset]'2026-11-21T12:00:00Z'
        $device = [pscustomobject]@{
            id = 'mock-123'; deviceName = 'LAB-WIN-03'
            operatingSystem = 'Windows'; complianceState = 'compliant'
            lastSyncDateTime = '2026-11-20T08:00:00Z'
        }
        $result = $device | Get-EndpointComplianceAudit -Now $now
        $result.Risk | Should -Be 'low'
        $result.Platform | Should -Be 'Windows'
        $result.Id | Should -Be 'mock-123'
    }

    It 'recognizes stale Workspace ONE records' {
        $device = [pscustomobject]@{
            Id = 'ws1-001'; DeviceFriendlyName = 'LAB-MAC-01'
            Platform = 'macOS'; ComplianceStatus = 'compliant'
            LastSeen = '2026-01-01T00:00:00Z'
        }
        $result = $device | Get-EndpointComplianceAudit -Now ([datetimeoffset]'2026-11-21T12:00:00Z')
        $result.Risk | Should -Be 'medium'
        $result.Freshness | Should -Be 'stale'
    }

    It 'does not treat malformed, naive or far-future dates as healthy' {
        foreach ($value in @('not-a-date', '2026-11-20T00:00:00', '2099-01-01T00:00:00Z')) {
            $device = [pscustomobject]@{ complianceState = 'compliant'; lastSyncDateTime = $value }
            $result = $device | Get-EndpointComplianceAudit -Now ([datetimeoffset]'2026-11-21T12:00:00Z')
            $result.Risk | Should -Be 'unknown'
        }
    }
}

Describe 'Offline compliance reports' {
    It 'writes local, usable JSON and CSV with summary totals' {
        $output = Join-Path $TestDrive 'report'
        $input = Join-Path $PSScriptRoot '../examples/devices.json'
        & "$PSScriptRoot/../powershell/Invoke-EndpointComplianceReport.ps1" -InputPath $input -OutDirectory $output -Now ([datetimeoffset]'2026-11-21T12:00:00Z')
        (Test-Path (Join-Path $output 'report.json')) | Should -BeTrue
        (Test-Path (Join-Path $output 'inventory.csv')) | Should -BeTrue
        $report = Get-Content (Join-Path $output 'report.json') -Raw | ConvertFrom-Json
        $report.summary.total | Should -Be 3
        $report.summary.high | Should -Be 1
        @(Import-Csv (Join-Path $output 'inventory.csv')).Count | Should -Be 3
    }

    It 'escapes CSV formulas in untrusted device names' {
        $input = Join-Path $TestDrive 'malicious.json'
        '[{"id":"lab-123","deviceName":"=2+2","complianceState":"compliant","lastSyncDateTime":"2026-11-20T00:00:00Z"}]' |
            Set-Content $input
        $out = Join-Path $TestDrive 'safe'
        & "$PSScriptRoot/../powershell/Invoke-EndpointComplianceReport.ps1" -InputPath $input -OutDirectory $out -Now ([datetimeoffset]'2026-11-21T12:00:00Z')
        $row = Import-Csv (Join-Path $out 'inventory.csv') | Select-Object -First 1
        $row.Name | Should -Be "'=2+2"
    }
}
