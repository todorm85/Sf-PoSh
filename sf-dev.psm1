Set-Location ${PSScriptRoot}

. "./bootstrap/bootstrap.ps1"

. "./core/manager/init.ps1"

Export-ModuleMember -Function * -Alias *
