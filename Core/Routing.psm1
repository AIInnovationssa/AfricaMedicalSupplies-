<#
.SYNOPSIS
    Sunil Africa EMS - API Gateway Router Framework
.DESCRIPTION
    Maps URI application request paths directly to executing business logic modules.
.NOTES
    Module: Core\Routing.psm1
    Version: 4.0.0
#>

$script:RouteRegistry = @{}

function Register-EMSRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Handler
    )
    process {
        $Key = "$Method`:$Path".ToLower()
        $script:RouteRegistry[$Key] = $Handler
    }
}

function Resolve-EMSRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    process {
        $Key = "$Method`:$Path".ToLower()
        if ($script:RouteRegistry.ContainsKey($Key)) {
            return $script:RouteRegistry[$Key]
        }
        return $null
    }
}

Export-ModuleMember -Function Register-EMSRoute, Resolve-EMSRoute
