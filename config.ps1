# Environment Constants

# the path where provisioned sitefinity projects by the script will be created in
$script:projectsDirectory = "e:\sitefinities"

if (-not (Test-Path $projectsDirectory)) {
    throw "Projects directory not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs
$script:sqlServerInstance = '.'

# browser used to launch web apps by the script
$script:browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

if (-not (Test-Path $browserPath)) {
    throw "Browser path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# path to visual studio used to launch projects from the script
$script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" #VS2015
# $script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" #VS2017

if (-not (Test-Path $vsPath)) {
    throw "Visual studio path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# msbuild used by the script to build projects.
$script:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"  # VS2015
# $script:msBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe" VS2017

if (-not (Test-Path $msBuildPath)) {
    throw "MSBuild path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# used for tfs workspace manipulations, installed with Visual Studio
$script:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" #VS2015
# $script:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe" #VS2017

if (-not (Test-Path $tfPath)) {
    throw "Team foundation tool path not set in SfDevTool\EnvConstants.ps1 or it does not exist. (Used for tfs automation)"
}

# where info about created and imported sitefinities will be stored
$script:dataPath = "$($env:USERPROFILE)\db.xml"

# Preconfigured function shortcuts (aliases in powershell)
New-Alias -name ra -value sf-reset-app
New-Alias -name bw -value sf-browse-webSite
New-Alias -name rt -value sf-reset-thread
New-Alias -name rpo -value sf-reset-pool
New-Alias -name ns -value sf-new-sitefinity
New-Alias -name ss -value sf-select-sitefinity
New-Alias -name sd -value sf-set-description
New-Alias -name rs -value sf-rename-sitefinity
New-Alias -name s -value sf-show-currentSitefinity
New-Alias -name sa -value sf-show-allSitefinities
New-Alias -name os -value sf-open-solution
New-Alias -name up -value sf-undo-pendingChanges
New-Alias -name spc -value sf-show-pendingChanges
New-Alias -name gla -value sf-get-latest
New-Alias -name go -value sf-goto
New-Alias -name gpi -value sf-get-poolId
New-Alias -name sas -value sf-save-appState
New-Alias -name ras -value sf-restore-appState
New-Alias -name das -value sf-delete-appState
