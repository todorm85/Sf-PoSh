$GLOBAL:sf = [PSCustomObject]@{ }
$elapsedModule = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Start loading module."
Add-Member -InputObject $GLOBAL:sf -MemberType NoteProperty -Name appRelativeServerCodeRootPath -Value "App_Code\sf-posh-extensions"

$Script:moduleUserDir = "$Global:HOME\documents\sf-posh"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

Import-Module WebAdministration -Force

. "$PSScriptRoot\bootstrap\init-config.ps1"
. "$PSScriptRoot\bootstrap\initialize-events.ps1"
. "$PSScriptRoot\bootstrap\init-psPrompt.ps1"
. "$PSScriptRoot\bootstrap\load-scripts.ps1"

# $public = _getFunctionNames -exportPrivate $exportPrivate
# Export-ModuleMember -Function * -Alias *

$elapsedModule.Stop();
Write-Host "Total module load time: $($elapsedModule.Elapsed.TotalSeconds) second(s)"