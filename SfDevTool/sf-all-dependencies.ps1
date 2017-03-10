Set-Location ${PSScriptRoot} # need to be loaded like this for intelisense in VS CODE

# Common
. .\common\iis.ps1
. .\common\sql.ps1
. .\common\os.ps1
. .\common\tfs.ps1

# Core
. .\core\sf-data.ps1
. .\core\sf-iis.ps1
. .\core\sf-instance.ps1
. .\core\sf-solution.ps1
. .\core\sf-app.ps1

# Extensions
. .\extensions\sfe-configs.ps1
. .\extensions\sfe-app.ps1
. .\extensions\sfe-solution.ps1
. .\extensions\sfe-tfs.ps1
. .\extensions\sfe-iis.ps1

# Tests tooling
. .\tests\sfTest-common.ps1
. .\tests\sfTest-runner.ps1
. .\tests\sfTest-comparer.ps1
. .\tests\sfTest-converter.ps1