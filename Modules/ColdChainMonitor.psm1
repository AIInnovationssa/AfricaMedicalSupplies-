<#
.SYNOPSIS
    Sunil Africa EMS - Cold Chain Telemetry Monitoring Module
.DESCRIPTION
    Tracks climate telemetry metrics for vaccine cold-packs, blood products, and reagents.
    Enforces temperature boundary matrices and flags safe zone breaches instantly.
.NOTES
    Module: Modules\ColdChainMonitor.psm1
    Version: 4.0.0
    Dependency: Core\DatabaseEngine.psm1, Core\Logging.psm1
#>

Import-Module (Join-Path $PSScriptRoot "..\Core\DatabaseEngine.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "..\Core\Logging.psm1") -ErrorAction SilentlyContinue

# Safe temperature windows for critical classes
$script:ThermalProfiles = @{
    "ULTRA_LOW"   = @{ Min = -80.0; Max = -60.0 }  # mRNA Vaccines
    "FREEZER"     = @{ Min = -25.0; Max = -15.0 }  # Standard Frozen Assets
    "REFRIGERATED"= @{ Min = 2.0;   Max = 8.0 }    # Insulin, Standard Vaccines
}

### --- Public Telemetry Functions --- ###

function Submit-EMSTelemetry {
    <#
    .SYNOPSIS
        Logs a single sensor reading and runs thermal breach boundary analysis.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$NodeIdentifier,
        [Parameter(Mandatory = $true)] [double]$Temperature,
        [Parameter(Mandatory = $false)] [double]$Humidity = 0.0,
        [Parameter(Mandatory = $false)] [string]$ProfileKey = "REFRIGERATED"
    )

    process {
        $AlarmTripped = 0
        
        # Guard clause check against thermal envelope matrix rules
        if ($script:ThermalProfiles.ContainsKey($ProfileKey)) {
            $Limits = $script:ThermalProfiles[$ProfileKey]
            if ($Temperature -lt $Limits.Min -or $Temperature -gt $Limits.Max) {
                $AlarmTripped = 1
                Write-EMSLog -Severity "COMPLIANCE" -Component "COLD_CHAIN" `
                    -Message "THERMAL ENVELOPE BREACH on Node ($NodeIdentifier): Measured $Temperature°C outside standard profile limits ($($Limits.Min)°C to $($Limits.Max)°C)."
            }
        }

        $Query = @"
        INSERT INTO cc_telemetry (node_identifier, recorded_temperature, humidity_percentage, alarm_tripped)
        VALUES (@node, @temp, @humidity, @alarm);
"@
        $Params = @{
            "@node"     = $NodeIdentifier
            "@temp"     = $Temperature
            "@humidity" = $Humidity
            "@alarm"    = $AlarmTripped
        }

        try {
            $Rows = Invoke-EMSQuietQuery -Query $Query -Parameters $Params
            if ($Rows -gt 0 -and $AlarmTripped -eq 0) {
                Write-EMSLog -Severity "INFO" -Component "COLD_CHAIN" -Message "Telemetry packet logged normally for node: $NodeIdentifier ($Temperature°C)"
            }
            return $true
        }
        catch {
            Write-EMSLog -Severity "ERROR" -Component "COLD_CHAIN" -Message "Failed to persist streaming telemetry for node $NodeIdentifier: $_"
            throw $_
        }
    }
}

function Get-EMSActiveAlarms {
    <#
    .SYNOPSIS
        Returns all recent climate profiles currently flagged in an active alarm state.
    #>
    [CmdletBinding()]
    param()

    process {
        $Query = "SELECT log_id, node_identifier, recorded_temperature, humidity_percentage, timestamp FROM cc_telemetry WHERE alarm_tripped = 1 ORDER BY log_id DESC LIMIT 50;"
        return Invoke-EMSDataQuery -Query $Query
    }
}

Export-ModuleMember -Function Submit-EMSTelemetry, Get-EMSActiveAlarms
