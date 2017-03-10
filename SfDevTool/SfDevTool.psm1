. ${PSScriptRoot}\EnvConstants.ps1

# Dependencies
. ${PSScriptRoot}\sf-all-dependencies.ps1

# Startup
_sfData-init-data

Export-ModuleMember -Function * -Alias *