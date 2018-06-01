Set-Location ${PSScriptRoot}

. "./init/init-config.ps1"
. "./init/init-psPrompt.ps1"
. "./init/load-scripts.ps1"
. "./init/start.ps1"

Export-ModuleMember -Function * -Alias *
