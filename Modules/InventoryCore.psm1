<#
.SYNOPSIS
    Sunil Africa EMS - Inventory Management Business Logic Module
.DESCRIPTION
    Manages cold chain supplies, pharmaceuticals, and critical medical asset levels.
    Features automated safety stock checks and real-time inventory reorder triggers.
.NOTES
    Module: Modules\InventoryCore.psm1
    Version: 4.0.0
    Dependency: Core\DatabaseEngine.psm1, Core\Logging.psm1
#>

# Dynamically link upstream architecture blocks
Import-Module (Join-Path $PSScriptRoot "..\Core\DatabaseEngine.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "..\Core\Logging.psm1") -ErrorAction SilentlyContinue

### --- Public Inventory Functions --- ###

function Add-EMSProduct {
    <#
    .SYNOPSIS
        Registers a new tracking item SKU cleanly inside the relational master catalog.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$SKU,
        [Parameter(Mandatory = $true)] [string]$ProductName,
        [Parameter(Mandatory = $true)] [string]$Category,
        [Parameter(Mandatory = $false)] [int]$SafetyStock = 10,
        [Parameter(Mandatory = $false)] [double]$UnitPrice = 0.00
    )

    process {
        $Query = @"
        INSERT INTO inv_products (sku, product_name, category, safety_stock, current_balance, unit_price)
        VALUES (@sku, @product_name, @category, @safety_stock, 0, @unit_price);
"@
        $Params = @{
            "@sku"          = $SKU
            "@product_name" = $ProductName
            "@category"     = $Category
            "@safety_stock" = $SafetyStock
            "@unit_price"   = $UnitPrice
        }

        try {
            $Rows = Invoke-EMSQuietQuery -Query $Query -Parameters $Params
            if ($Rows -gt 0) {
                Write-EMSLog -Severity "INFO" -Component "INVENTORY" -Message "Successfully cataloged new item SKU: $SKU ($ProductName)"
                return $true
            }
        }
        catch {
            Write-EMSLog -Severity "ERROR" -Component "INVENTORY" -Message "Failed to catalog product SKU $SKU: $_"
            throw $_
        }
        return $false
    }
}

function Update-EMSSplitStock {
    <#
    .SYNOPSIS
        Modifies current warehouse physical balance sheets and asserts safety thresholds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$SKU,
        [Parameter(Mandatory = $true)] [int]$QuantityDelta
    )

    process {
        # Fetch existing product thresholds to cross-analyze
        $CheckQuery = "SELECT product_name, current_balance, safety_stock FROM inv_products WHERE sku = @sku;"
        $Product = Invoke-EMSDataQuery -Query $CheckQuery -Parameters @{"@sku" = $SKU} | Select-Object -First 1

        if ($null -eq $Product) {
            throw "Target inventory reference map missing for SKU: $SKU"
        }

        $NewBalance = $Product.current_balance + $QuantityDelta
        if ($NewBalance -lt 0) {
            throw "Inventory depletion rejection: Transaction would drop '$($Product.product_name)' into negative allocations ($NewBalance)."
        }

        $UpdateQuery = "UPDATE inv_products SET current_balance = @new_balance, last_updated = CURRENT_TIMESTAMP WHERE sku = @sku;"
        Invoke-EMSQuietQuery -Query $UpdateQuery -Parameters @{"@new_balance" = $NewBalance; "@sku" = $SKU} | Out-Null

        Write-EMSLog -Severity "INFO" -Component "INVENTORY" -Message "Updated SKU $SKU quantity by $QuantityDelta. New balance: $NewBalance"

        # Automated Safety Stock Floor Monitoring Engine Trigger
        if ($NewBalance -le $Product.safety_stock) {
            Write-EMSLog -Severity "WARN" -Component "INVENTORY" -Message "CRITICAL STOCK BREACH: SKU $SKU ($($Product.product_name)) has dropped below safety margin ($NewBalance / $($Product.safety_stock)). Procurement run required."
        }

        return $true
    }
}

function Get-EMSActiveInventory {
    <#
    .SYNOPSIS
        Returns all registered inventory items along with safety threshold warnings.
    #>
    [CmdletBinding()]
    param()

    process {
        $Query = "SELECT sku, product_name, category, safety_stock, current_balance, unit_price FROM inv_products ORDER BY product_name ASC;"
        return Invoke-EMSDataQuery -Query $Query
    }
}

Export-ModuleMember -Function Add-EMSProduct, Update-EMSSplitStock, Get-EMSActiveInventory
