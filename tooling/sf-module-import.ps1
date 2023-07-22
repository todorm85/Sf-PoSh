param([ValidateSet("dev", "e2e", "live")][string]$env)

. "$PSScriptRoot\constants.ps1"

if (!$env -and !$global:sfposhenv) {
    throw "You must specify an environment on first run!"
}
    
$currentProject = $null
try {
    $currentProject = sf-project-get
}
catch {
    Write-Verbose "No project selected."
}

if ($global:sfposhenv) {
    Remove-Module sf-posh -Force
}

if (!$env) {
    $env = $global:sfposhenv
}

if ($global:sfposhenv) {
    $toRemove = $global:sfposhenv
    [System.Console]::Title = [System.Console]::Title.Replace(" ($($toRemove.ToUpper()))", "")
}

[System.Console]::Title = "$([System.Console]::Title) ($($env.ToUpper()))"

$keepProject = $global:sfposhenv -eq $env
    
$global:sfposhenv = $env

$Global:SfEvents_OnAfterConfigInit = @()
switch ($env) {
    "dev" { 
        $sfPoshPath = "$sfPoshDevPath\sf-posh.psd1"
        $Global:SfEvents_OnAfterConfigInit += {
            . "$Global:sfPoshDevTestsPath\common-config.ps1"
        }
    }
    "e2e" { 
        $sfPoshPath = "$sfPoshDevPath\sf-posh.psd1"
        $Global:SfEvents_OnAfterConfigInit += {
            . "$Global:sfPoshDevTestsPath\e2e-tests-config.ps1"
        }
    }
    "live" { 
        $sfPoshPath = "$sfPoshLivePath\sf-posh.psd1"
    }
    Default { }
}

Import-Module $sfPoshPath -Force

$Global:SfEvents_OnAfterProjectSet += {
    [System.Console]::Title = "$([System.Console]::Title) ($($global:sfposhenv.ToUpper()))"
}
    
$Global:InformationPreference = "Continue"
if ($keepProject -and $currentProject) {
    sf-project-get -all | ? id -eq $currentProject.id | sf-project-setCurrent
}