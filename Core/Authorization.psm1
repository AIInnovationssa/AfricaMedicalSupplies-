<#
.SYNOPSIS
    Sunil Africa EMS - Role-Based Access Control (RBAC) Authorization Engine
.DESCRIPTION
    Provides systemic verification of domain operations against defined role-permission 
    matrices. Governs execution barriers based on assigned structural profiles.
.NOTES
    Module: Core\Authorization.psm1
    Version: 4.0.0
    Compliance: ISO 9001, GDP
#>

# Module-scoped static master mapping rules matrix
$script:RolePermissionMatrix = @{
    "SystemAdmin" = @("all")
    "WarehouseOperator" = @("inv:read", "inv:write", "cc:read")
    "ColdChainManager" = @("cc:read", "cc:write", "cc:override")
    "ProcurementOfficer" = @("proc:read", "proc:write", "inv:read")
    "FinanceAuditor" = @("fin:read", "fin:audit")
}

### --- Public Security Functions --- ###

function Get-EMSRolePermissions {
    <#
    .SYNOPSIS
        Retrieves the exact permission string array explicitly assigned to an architecture role profile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )

    process {
        if ($script:RolePermissionMatrix.ContainsKey($RoleName)) {
            return $script:RolePermissionMatrix[$RoleName]
        }
        return @()
    }
}

function Test-EMSPermission {
    <#
    .SYNOPSIS
        Asserts if a given role is explicitly authorized to execute a specific module operation token.
    .OUTPUTS
        [Boolean] True if verified, False if access execution is denied.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [string]$RequiredPermission
    )

    process {
        $AssignedPermissions = Get-EMSRolePermissions -RoleName $RoleName
        
        # System Admin bypass rule
        if ($AssignedPermissions -contains "all") { return $true }
        
        # Verify targeted permission token exists inside the verified user roles matrix array
        if ($AssignedPermissions -contains $RequiredPermission) {
            return $true
        }
        
        return $false
    }
}

function Register-EMSDynamicPermission {
    <#
    .SYNOPSIS
        Allows running plugins or enterprise compliance rules to dynamically extend runtime roles.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [string]$NewPermission
    )

    process {
        if (-not $script:RolePermissionMatrix.ContainsKey($RoleName)) {
            $script:RolePermissionMatrix[$RoleName] = @()
        }
        
        if ($script:RolePermissionMatrix[$RoleName] -notcontains $NewPermission) {
            $script:RolePermissionMatrix[$RoleName] += $NewPermission
        }
        return $true
    }
}

Export-ModuleMember -Function Get-EMSRolePermissions, Test-EMSPermission, Register-EMSDynamicPermission
