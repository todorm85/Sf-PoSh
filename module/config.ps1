# the path where provisioned sitefinity projects by the script will be created in. The directory must exist.
$script:projectsDirectory = ""

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs.
$script:sqlServerInstance = '.'

# browser used to launch web apps by the script
$script:browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

# path to visual studio used to launch projects from the script
# $script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" #VS2015
$script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" #VS2017
$script:vsCmdPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.com" #VS2017

# msbuild used by the script to build projects.
# $script:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"  # VS2015
$script:msBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe" #VS2017

# where info about created and imported sitefinities will be stored
$script:dataPath = "${PSScriptRoot}\db.xml"

# Preconfigured function shortcuts (aliases in powershell)

New-Alias -name s -value sf-select-project
New-Alias -Name dpr -Value sf-delete-projects
New-Alias -Name rpr -Value sf-rename-project

New-Alias -Name scp -Value sf-show-currentProject
New-Alias -Name sap -Value sf-show-projects

New-Alias -name o -value sf-open-solution

New-Alias -name b -value sf-browse-webSite

New-Alias -name rap -value sf-reset-app
New-Alias -name rpo -value sf-reset-pool

New-Alias -name nas -value sf-new-appState
New-Alias -name ras -value sf-restore-appState
New-Alias -name das -value sf-delete-appState

New-Alias -name sco -value sf-select-container
New-Alias -name spc -value sf-set-projectContainer

# Global settings
$script:defaultUser = ''
$script:defaultPassword = ''

$script:predefinedBranches = @("$/CMS/Sitefinity 4.0/Code Base",
"$/CMS/Sitefinity 4.0/TeamBranches/U3/Code Base")

$script:idPrefix = ""