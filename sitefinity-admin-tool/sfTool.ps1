# Dependencies
. "${PSScriptRoot}\..\EnvConstants.ps1"
. "${PSScriptRoot}\..\common\iis.ps1"
. "${PSScriptRoot}\..\common\sql.ps1" $sqlServerInstance
. "${PSScriptRoot}\..\common\os.ps1"
. "${PSScriptRoot}\..\common\tfs.ps1" $tfPath

# Core
. "${PSScriptRoot}\core\sf-data.ps1"
. "${PSScriptRoot}\core\sf-instance.ps1"
. "${PSScriptRoot}\core\sf-solution.ps1"
. "${PSScriptRoot}\core\sf-app.ps1"
. "${PSScriptRoot}\core\sf-configs.ps1"
. "${PSScriptRoot}\core\sf-iis.ps1"

# Modules
. "${PSScriptRoot}\modules\sf-dbp.ps1"
# . "${PSScriptRoot}\modules\sf-dec.ps1"

# Startup
_sfData-init-data
sf-select-sitefinity