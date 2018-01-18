# Set your Environment Constants and variables here then reload the module

# DELETE THIS LINE AFTER FINISHED CONFIGURATION!
throw "Please, configure the module before using in ${PSScriptRoot}\config.ps1"

# the path where provisioned sitefinity projects by the script will be created in. The directory must exist.
$script:projectsDirectory = "d:\sitefinities"

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs.
$script:sqlServerInstance = '.'

# browser used to launch web apps by the script
$script:browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

# path to visual studio used to launch projects from the script
# $script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" #VS2015
$script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" #VS2017

# msbuild used by the script to build projects.
# $script:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"  # VS2015
$script:msBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe" #VS2017

# used for tfs workspace manipulations, installed with Visual Studio
# $script:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" #VS2015
$script:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe" #VS2017

# where info about created and imported sitefinities will be stored
$script:dataPath = "$($env:USERPROFILE)\db.xml"

# Preconfigured function shortcuts (aliases in powershell)
New-Alias -name ra -value sf-reset-app
New-Alias -name bw -value sf-browse-webSite
New-Alias -name rt -value sf-reset-thread
New-Alias -name rpo -value sf-reset-pool
New-Alias -name ns -value sf-new-project
New-Alias -name ss -value sf-rename-project
New-Alias -name sd -value sf-set-description
New-Alias -name rs -value sf-rename-project
New-Alias -name s -value sf-show-currentProject
New-Alias -name sa -value sf-show-allProjects
New-Alias -name os -value sf-open-solution
New-Alias -name up -value sf-undo-pendingChanges
New-Alias -name spc -value sf-show-pendingChanges
New-Alias -name gla -value sf-get-latest
New-Alias -name go -value sf-goto
New-Alias -name gpi -value sf-get-poolId
New-Alias -name sas -value sf-save-appState
New-Alias -name ras -value sf-restore-appState
New-Alias -name das -value sf-delete-appState
New-Alias -name ds -value sf-delete-project

# Global settings
$defaultUser = 'admin@test.test'
$defaultPassword = 'admin@2'

$predefinedBranches = @("$/CMS/Sitefinity 4.0/Code Base",
"$/CMS/Sitefinity 4.0/TeamBranches/U3/Code Base",
"$/CMS/Sitefinity 4.0/OfficialReleases/Release_10_1_Fixes",
"$/CMS/Sitefinity 4.0/TeamBranches/U3/XSS")