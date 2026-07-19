<#
.SYNOPSIS
    Sunil Africa EMS - Desktop Server Bootstrap Loader
#>
[CmdletBinding()]
param([int]$Port = 8080)

# Import Application Kernel Core
Import-Module ".\Core\Application.psm1" -Force
Initialize-EMSApplication -Environment "Production" | Out-Null

$Listener = [System.Net.HttpListener]::New()
$Listener.Prefixes.Add("http://localhost:$Port/")
try {
    $Listener.Start()
    Write-Host "Sunil Africa EMS running smoothly at http://localhost:$Port/" -ForegroundColor Green
    Write-Host "Press Ctrl+C to halt server execution gracefully." -ForegroundColor Yellow
    
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Response = $Context.Response
        $HTMLPath = Join-Path $PSScriptRoot "Pages\Dashboard\index.html"
        $Buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw $HTMLPath))
        $Response.ContentLength64 = $Buffer.Length
        $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        $Response.OutputStream.Close()
    }
} catch {
    $Listener.Stop()
}
