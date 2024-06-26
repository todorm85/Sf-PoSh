# Get Nuget.exe
$nugetDownloadLink = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$toolDir = "$Script:moduleUserDir\external-tools\nuget"
if (!(Test-Path $toolDir)) {
    New-Item -Path $toolDir -ItemType Directory
}

$Script:nugetExePath = "$toolDir\nuget.exe"

function _nuget-downloadExe {
    if (!(Test-Path $nugetExePath)) {
        try {
            Invoke-WebRequest -Uri $nugetDownloadLink -OutFile $nugetExePath
        }
        catch {
            Write-Error "Error fetching the nuget tool from $nugetDownloadLink nuget operations might not work"
        }
    }
}

_nuget-downloadExe

function os-nuget-clearCache {
    execute-native "& `"$Script:nugetExePath`" locals all -clear"
}

function sf-module-updateNugetExe {
    Remove-Item $Script:nugetExePath -Force
    _nuget-downloadExe
}
