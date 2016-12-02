$sfToolLoaded = $true

# Dependencies
. "${PSScriptRoot}\EnvConstants.ps1"
. "${PSScriptRoot}\common\iis.ps1"
. "${PSScriptRoot}\common\sql.ps1" $sqlServerInstance
. "${PSScriptRoot}\common\os.ps1"
. "${PSScriptRoot}\common\tfs.ps1" $tfPath

# Core
. "${PSScriptRoot}\core\sf-data.ps1"
. "${PSScriptRoot}\core\sf-iis.ps1"
. "${PSScriptRoot}\core\sf-instance.ps1"
. "${PSScriptRoot}\core\sf-solution.ps1"
. "${PSScriptRoot}\core\sf-app.ps1"

# Extensions
. "${PSScriptRoot}\extensions\sfe-dbp.ps1"
. "${PSScriptRoot}\extensions\sfe-tests.ps1"
. "${PSScriptRoot}\extensions\sfe-configs.ps1"
. "${PSScriptRoot}\extensions\sfe-app.ps1"
. "${PSScriptRoot}\extensions\sfe-iis.ps1"
. "${PSScriptRoot}\extensions\sfe-solution.ps1"
. "${PSScriptRoot}\extensions\sfe-dec.ps1"
. "${PSScriptRoot}\extensions\sfe-tfs.ps1"

# Startup
# Start-Sleep 2
_sfData-init-data
# sf-select-sitefinity