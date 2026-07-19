$script:RuntimeState = @{ IsInitialized = $true; SystemStatus = "Running" }
function Initialize-EMSApplication { return $script:RuntimeState }
Export-ModuleMember -Function Initialize-EMSApplication
