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

# initialize
$defaultContainerName = _sfData-get-defaultContainerName
if ($defaultContainerName -ne '') {
    $script:selectedContainer = _sfData-get-allContainers | Where-Object {$_.name -eq $defaultContainerName}
}
else {
    $script:selectedContainer = [PSCustomObject]@{ name = "" }
}

function Global:prompt
{
    Write-Host "PS $(Get-Location)> " -NoNewline
    Write-Host "[$(sf-show-currentProject)]" -ForegroundColor Green -NoNewline
    return " "
}

Export-ModuleMember -Function * -Alias *
