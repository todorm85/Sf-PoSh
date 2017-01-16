# Dependencies
. "${PSScriptRoot}\EnvConstants.ps1"
. "${PSScriptRoot}\common\iis.ps1"
. "${PSScriptRoot}\common\sql.ps1"
. "${PSScriptRoot}\common\os.ps1"
. "${PSScriptRoot}\common\tfs.ps1"

# Core
. "${PSScriptRoot}\core\sf-data.ps1"
. "${PSScriptRoot}\core\sf-iis.ps1"
. "${PSScriptRoot}\core\sf-instance.ps1"
. "${PSScriptRoot}\core\sf-solution.ps1"
. "${PSScriptRoot}\core\sf-app.ps1"

# Extensions
. "${PSScriptRoot}\extensions\sfe-configs.ps1"
. "${PSScriptRoot}\extensions\sfe-app.ps1"
. "${PSScriptRoot}\extensions\sfe-iis.ps1"
. "${PSScriptRoot}\extensions\sfe-solution.ps1"
. "${PSScriptRoot}\extensions\sfe-tfs.ps1"

# Startup
_sfData-init-data

Export-ModuleMember -Function * -Alias *