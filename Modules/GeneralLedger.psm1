<#
.SYNOPSIS
    Sunil Africa EMS - Financial General Ledger Accounting Kernel
.DESCRIPTION
    Tracks transaction double-entry journals, inventory capital valuation mapping,
    and fiscal accounting audits across multi-country operations.
.NOTES
    Module: Modules\GeneralLedger.psm1
    Version: 4.0.0
    Dependency: Core\DatabaseEngine.psm1, Core\Logging.psm1
#>

Import-Module (Join-Path $PSScriptRoot "..\Core\DatabaseEngine.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "..\Core\Logging.psm1") -ErrorAction SilentlyContinue

### --- Initialization Routine --- ###

function Initialize-EMSLedgerSchema {
    [CmdletBinding()]
    param()

    $TableQuery = @"
    CREATE TABLE IF NOT EXISTS fin_ledger (
        entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_code TEXT NOT NULL,
        entry_type TEXT NOT NULL CHECK(entry_type IN ('DEBIT', 'CREDIT')),
        amount REAL NOT NULL,
        reference_token TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"@
    Invoke-EMSQuietQuery -Query $TableQuery | Out-Null
}

### --- Public Ledger Functions --- ###

function Post-EMSLedgerEntry {
    <#
    .SYNOPSIS
        Commits a secure double-entry transactional node record into the compliance log ledger.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$AccountCode,
        [Parameter(Mandatory = $true)] [ValidateSet("DEBIT", "CREDIT")] [string]$EntryType,
        [Parameter(Mandatory = $true)] [double]$Amount,
        [Parameter(Mandatory = $false)] [string]$ReferenceToken = "GENERAL"
    )

    process {
        Initialize-EMSLedgerSchema
        
        $Query = @"
        INSERT INTO fin_ledger (account_code, entry_type, amount, reference_token)
        VALUES (@account, @type, @amount, @ref);
"@
        $Params = @{
            "@account" = $AccountCode
            "@type"    = $EntryType
            "@amount"  = $Amount
            "@ref"     = $ReferenceToken
        }

        try {
            $Rows = Invoke-EMSQuietQuery -Query $Query -Parameters $Params
            if ($Rows -gt 0) {
                Write-EMSLog -Severity "INFO" -Component "FINANCE" -Message "Posted $EntryType of $Amount to Account $AccountCode [Ref: $ReferenceToken]"
                return $true
            }
        }
        catch {
            Write-EMSLog -Severity "ERROR" -Component "FINANCE" -Message "Failed to write journal ledger entry for Account $AccountCode: $_"
            throw $_
        }
        return $false
    }
}

function Get-EMSInventoryValuation {
    <#
    .SYNOPSIS
        Calculates full financial valuation balances across all registered asset categories.
    #>
    [CmdletBinding()]
    param()

    process {
        $Query = "SELECT SUM(current_balance * unit_price) AS TotalValuation FROM inv_products;"
        $Result = Invoke-EMSDataQuery -Query $Query | Select-Object -First 1
        
        if ($null -eq $Result -or $null -eq $Result.TotalValuation) {
            return 0.00
        }
        return [math]::Round([double]$Result.TotalValuation, 2)
    }
}

Export-ModuleMember -Function Post-EMSLedgerEntry, Get-EMSInventoryValuation
