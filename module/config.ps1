# the path where provisioned sitefinity projects by the script will be created in. The directory must exist.
$global:projectsDirectory = ""

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs.
$global:sqlServerInstance = '.'

# browser used to launch web apps by the script
$global:browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

# path to visual studio used to launch projects from the script
# $global:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" #VS2015
$global:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" #VS2017

# msbuild used by the script to build projects.
# $global:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"  # VS2015
$global:msBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe" #VS2017

# where info about created and imported sitefinities will be stored
$global:dataPath = "${PSScriptRoot}\db.xml"

# Global settings
$global:defaultUser = ''
$global:defaultPassword = ''

$global:predefinedBranches = @("$/CMS/Sitefinity 4.0/Code Base",
"$/CMS/Sitefinity 4.0/TeamBranches/U3/Code Base")

$global:idPrefix = ""