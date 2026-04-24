function get-userConfig {
    param (
        [Parameter(Mandatory=$true)][string]$defaultConfigPath,
        [Parameter(Mandatory=$true)][string]$userConfigPath
    )

    if (!(Test-Path $defaultConfigPath)) {
        throw "Default config path not found."
    }

    $defaultConfig = Get-Content $defaultConfigPath | ConvertFrom-Json

    if (!(Test-Path $userConfigPath)) {
        $defaultConfig | ConvertTo-Json | Out-File $userConfigPath
        $userConfig = $defaultConfig
    }
    else {
        try {
            $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
        }
        catch {
            throw "Corrupted user config at $userConfigPath. Probably not a json format? Inner exception: $_"
        }

        if (!$userConfig) {
            $userConfig = New-Object -TypeName psobject
        }

        # create new properties from default
        $defaultConfig.PSObject.Properties | ForEach-Object {
            if (!$userConfig.PSObject.Properties.Match($_.Name).length) {
                $userConfig | Add-Member -Type NoteProperty -Name $_.Name -Value $_.Value
            }
        }
        # remove unused properties from user
        $userConfig.PSObject.Properties | ForEach-Object {
            if (!$defaultConfig.PSObject.Properties.Match($_.Name).length) {
                $userConfig.PSObject.Properties.Remove($_.Name)
            }
        }

        $userConfig | ConvertTo-Json | Out-File $userConfigPath
    }

    return $userConfig
}

$Script:userConfigPath = "$Script:moduleUserDir\config.json"
$defaultConfigPath = "$PSScriptRoot\default_config.json"

$configFile = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
Add-Member -InputObject $configFile -MemberType NoteProperty -Name userConfigPath -Value $userConfigPath
Add-Member -InputObject $configFile -MemberType NoteProperty -Name dataPath -Value "$Script:moduleUserDir\db.xml"
$configFile.projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($configFile.projectsDirectory)

if (Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe") {
    $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
    -latest -requires Microsoft.Component.MSBuild -property installationPath
    $configFile.msBuildPath = "$vs\MSBuild\Current\Bin\MSBuild.exe"
}

Add-Member -InputObject $GLOBAL:sf -MemberType NoteProperty -Name config -Value $configFile

if ($Global:SfEvents_OnAfterConfigInit) {
    $Global:SfEvents_OnAfterConfigInit | % { Invoke-Command -ScriptBlock $_ }
}