<#
.SYNOPSIS
    Sunil Africa EMS - Central Core Service Integration Gateway Controller
.DESCRIPTION
    Launches internal network integration ports, bootstraps modular components,
    and runs the foundational server loop processing dashboard application traffic.
.NOTES
    File: Public\Gateway.ps1
    Version: 4.0.0
#>

# 1. Enforce strict architectural component layout discoveries
$ArchitectureRoot = Split-Path $PSScriptRoot -Parent
$CorePath = Join-Path $ArchitectureRoot "Core"
$ModulesPath = Join-Path $ArchitectureRoot "Modules"
$PagesPath = Join-Path $ArchitectureRoot "Pages"

Write-Host "Bootstrapping Sunil Africa EMS Environment Layer..." -ForegroundColor Cyan

# Load Core Infrastructure Elements
Import-Module (Join-Path $CorePath "DatabaseEngine.psm1") -Force
Import-Module (Join-Path $CorePath "Authentication.psm1") -Force
Import-Module (Join-Path $CorePath "Authorization.psm1") -Force
Import-Module (Join-Path $CorePath "Routing.psm1") -Force
Import-Module (Join-Path $CorePath "Logging.psm1") -Force

# Load Domain Business Logic Blocks
Import-Module (Join-Path $ModulesPath "InventoryCore.psm1") -Force
Import-Module (Join-Path $ModulesPath "ColdChainMonitor.psm1") -Force
Import-Module (Join-Path $ModulesPath "Procurement.psm1") -Force
Import-Module (Join-Path $ModulesPath "GeneralLedger.psm1") -Force

# 2. Verify relational file schema layers exist on runtime engines
Initialize-EMSDatabaseSchema

# 3. Spin up local integration network port listeners
$Port = 8080
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:$Port/")

try {
    $Listener.Start()
    Write-EMSLog -Severity "INFO" -Component "GATEWAY" -Message "Sunil Africa EMS Network Listener successfully bound to port $Port."
    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host "🚀 EMS SERVER SYSTEM ONLINE: Running on http://localhost:$Port" -ForegroundColor Green
    Write-Host "🖥️ Design Profile: Windows 11 Light Theme Dashboard Interactive View" -ForegroundColor Green
    Write-Host "⚠️  Press [Ctrl + C] within this PowerShell session to spin down." -ForegroundColor Yellow
    Write-Host "=================================================================`n" -ForegroundColor Green

    # Start the core network operational polling engine loop
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        $CleanPath = $Request.Url.AbsolutePath
        Write-EMSLog -Severity "INFO" -Component "GATEWAY" -Message "Processing incoming endpoint intercept: $($Request.HttpMethod) $CleanPath"

        # Serve static Windows 11 dashboard UI layout instantly
        if ($CleanPath -eq "/" -or $CleanPath -eq "/index.html") {
            $TargetFile = Join-Path $PagesPath "Dashboard\index.html"
            if (Test-Path $TargetFile) {
                [byte[]]$Buffer = [System.IO.File]::ReadAllBytes($TargetFile)
                $Response.ContentType = "text/html; charset=utf-8"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            } else {
                $Response.StatusCode = 404
            }
        }
        else {
            # Catch-all fallback default handler
            $Response.StatusCode = 404
        }

        $Response.OutputStream.Close()
    }
}
catch {
    Write-EMSLog -Severity "ERROR" -Component "GATEWAY" -Message "Fatal crash loop anomaly encountered on Service Framework: $_"
    Write-Host "Gateway Engine interrupted: $_" -ForegroundColor Red
}
finally {
    if ($null -ne $Listener) {
        $Listener.Stop()
        $Listener.Close()
    }
}
