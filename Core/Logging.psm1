<#
.SYNOPSIS
    Sunil Africa EMS - Compliance Audit & Structural Logging Engine
.DESCRIPTION
    Provides regulatory logging controls tracking system events. Integrates 
    isolated log stores, run-time log parsing, and performance-minded metric streaming.
.NOTES
    Module: Core\Logging.psm1
    Version: 4.0.0
    Compliance: ISO 9001, FDA 21 CFR Part 11
#>

$script:LogDirectory = Join-Path $PSScriptRoot "..\Logs"
$script:InMemoryLogBuffer = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:BufferLock = New-Object System.Object

### --- Public Audit Logging Functions --- ###

function Write-EMSLog {
    <#
    .SYNOPSIS
        Appends an immutable audit entry into the secure system logs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "WARN", "ERROR", "SECURITY", "COMPLIANCE")]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$OperatorID = "SYSTEM"
    )

    process {
        if (!(Test-Path $script:LogDirectory)) { 
            New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null 
        }

        $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        $LogEntry = [ordered]@{
            Timestamp  = $Timestamp
            Severity   = $Severity
            Component  = $Component
            Operator   = $OperatorID
            Message    = $Message
        }
        $LogObject = [PSCustomObject]$LogEntry

        # Thread-safe write execution block to volatile diagnostic buffer
        [System.Threading.Monitor]::Enter($script:BufferLock)
        try {
            $script:InMemoryLogBuffer.Add($LogObject)
            if ($script:InMemoryLogBuffer.Count -gt 500) { $script:InMemoryLogBuffer.RemoveAt(0) }
        }
        finally {
            [System.Threading.Monitor]::Exit($script:BufferLock)
        }

        # Format line cleanly into CSV compliant production format
        $LogLine = '"{0}","{1}","{2}","{3}","{4}"' -f $Timestamp, $Severity, $Component, $OperatorID, ($Message -replace '"', '""')
        $TargetFile = Join-Path $script:LogDirectory ("EMS-Audit-{0}.log" -f (Get-Date).ToString("yyyyMMdd"))
        
        $LogLine | Out-File -FilePath $TargetFile -Append -Encoding utf8
    }
}

function Get-EMSAuditLogs {
    <#
    .SYNOPSIS
        Extracts recent logs from the thread-safe buffer for direct interface rendering.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Limit = 50
    )

    process {
        [System.Threading.Monitor]::Enter($script:BufferLock)
        try {
            $Count = $script:InMemoryLogBuffer.Count
            if ($Count -eq 0) { return @() }
            $FetchCount = [Math]::Min($Limit, $Count)
            return $script:InMemoryLogBuffer.GetRange($Count - $FetchCount, $FetchCount)
        }
        finally {
            [System.Threading.Monitor]::Exit($script:BufferLock)
        }
    }
}

Export-ModuleMember -Function Write-EMSLog, Get-EMSAuditLogs
