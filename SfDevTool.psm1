Set-Location ${PSScriptRoot}

# init config
$configPath = ".\config.ps1"
$defaultConfigPath = ".\config.default.ps1"
if (-not (Test-Path $configPath)) {
    Copy-Item $defaultConfigPath $configPath
}

# Load Config
. $configPath

# Load Manager
. .\manager\data.ps1
. .\manager\project.ps1

# Load Common
. .\infrastructure\iis.ps1
. .\infrastructure\sql.ps1
. .\infrastructure\os.ps1
. .\infrastructure\tfs.ps1

# Load Core
. .\core\solution.ps1
. .\core\webapp.ps1
. .\core\iis.ps1
. .\core\tfs.ps1


Export-ModuleMember -Function * -Alias *
