<#
.SYNOPSIS
    Sunil Africa EMS - Procurement & Vendor Fulfilment Engine
.DESCRIPTION
    Manages stock reorder pipelines, supplier procurement requests, and inbound tracking structures.
.NOTES
    Module: Modules\Procurement.psm1
    Version: 4.0.0
    Dependency: Core\DatabaseEngine.psm1, Core\Logging.psm1
#>

Import-Module (Join-Path $PSScriptRoot "..\Core\DatabaseEngine.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "..\Core\Logging.psm1") -ErrorAction SilentlyContinue

### --- Initialization Routine --- ###

function Initialize-EMSProcurementSchema {
    [CmdletBinding()]
    param()

    $TableQuery = @"
    CREATE TABLE IF NOT EXISTS proc_orders (
        order_id TEXT PRIMARY KEY,
        sku TEXT NOT NULL,
        supplier_name TEXT NOT NULL,
        order_quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        order_status TEXT DEFAULT 'PENDING',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(sku) REFERENCES inv_products(sku)
    );
"@
    Invoke-EMSQuietQuery -Query $TableQuery | Out-Null
}

### --- Public Procurement Functions --- ###

function New-EMSProcurementOrder {
    <#
    .SYNOPSIS
        Creates an authorized supplier purchase order request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$SKU,
        [Parameter(Mandatory = $true)] [string]$SupplierName,
        [Parameter(Mandatory = $true)] [int]$Quantity,
        [Parameter(Mandatory = $true)] [double]$UnitCost
    )

    process {
        Initialize-EMSProcurementSchema
        $OrderID = "PO-" + [Guid]::NewGuid().ToString("N").Substring(0,8).ToUpper()
        
        $Query = @"
        INSERT INTO proc_orders (order_id, sku, supplier_name, order_quantity, unit_cost, order_status)
        VALUES (@id, @sku, @supplier, @qty, @cost, 'PENDING');
"@
        $Params = @{
            "@id"       = $OrderID
            "@sku"      = $SKU
            "@supplier" = $SupplierName
            "@qty"      = $Quantity
            "@cost"     = $UnitCost
        }

        try {
            $Rows = Invoke-EMSQuietQuery -Query $Query -Parameters $Params
            if ($Rows -gt 0) {
                Write-EMSLog -Severity "INFO" -Component "PROCUREMENT" -Message "Generated Purchase Order $OrderID for SKU $SKU ($Quantity units)."
                return $OrderID
            }
        }
        catch {
            Write-EMSLog -Severity "ERROR" -Component "PROCUREMENT" -Message "Failed to generate Purchase Order for SKU $SKU: $_"
            throw $_
        }
    }
}

function Complete-EMSProcurementOrder {
    <#
    .SYNOPSIS
        Closes out an active order and dynamically steps up physical warehouse stock tallies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$OrderID
    )

    process {
        $FetchQuery = "SELECT sku, order_quantity, order_status FROM proc_orders WHERE order_id = @id;"
        $Order = Invoke-EMSDataQuery -Query $FetchQuery -Parameters @{"@id" = $OrderID} | Select-Object -First 1

        if ($null -eq $Order) { throw "Target Purchase Order reference missing: $OrderID" }
        if ($Order.order_status -eq "FULFILLED") { throw "Order $OrderID has already been marked as fulfilled." }

        # Dynamically bind inventory module to increment stock levels
        Import-Module (Join-Path $PSScriptRoot "..\Modules\InventoryCore.psm1") -ErrorAction Stop

        try {
            # Update order state cleanly
            $UpdateQuery = "UPDATE proc_orders SET order_status = 'FULFILLED' WHERE order_id = @id;"
            Invoke-EMSQuietQuery -Query $UpdateQuery -Parameters @{"@id" = $OrderID} | Out-Null

            # Push quantities onto warehouse floor cards
            Update-EMSSplitStock -SKU $Order.sku -QuantityDelta $Order.order_quantity | Out-Null

            Write-EMSLog -Severity "INFO" -Component "PROCUREMENT" -Message "Purchase Order $OrderID fulfilled successfully. Inbound stock integrated."
            return $true
        }
        catch {
            Write-EMSLog -Severity "ERROR" -Component "PROCUREMENT" -Message "Failed to fulfill Purchase Order $OrderID: $_"
            throw $_
        }
    }
}

Export-ModuleMember -Function New-EMSProcurementOrder, Complete-EMSProcurementOrder
