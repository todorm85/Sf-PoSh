. ${PSScriptRoot}\config.ps1

. ${PSScriptRoot}\sf-load-scripts.ps1

# Startup logic
_sfData-init-data

Export-ModuleMember -Function * -Alias *