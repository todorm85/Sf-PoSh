# the path where provisioned sitefinity projects by the script will be created in. The directory must exist. The default value $global:moduleUserDir points to %Userprofile%\Documents\sf-dev
$global:projectsDirectory = "$global:moduleUserDir"

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs. The default '.' notation references the local sql server
$global:sqlServerInstance = '.'

# browser used to launch web apps by the script
$global:browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

# path to visual studio used to launch projects from the script
# $global:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" #VS2015
$global:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" #VS2017

# used for tfs workspace manipulations, installed with Visual Studio
# $tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" #VS2015
$Global:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe" #VS2017
$Global:tfsServerName = "https://tfsemea.progress.com/defaultcollection"

# msbuild used by the script to build projects.
# $global:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"  # VS2015
$global:msBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe" #VS2017

# where the module will store info about projects
$global:dataPath = "$global:moduleUserDir\db.xml"

# Global settings
$global:defaultUser = 'admin@test.test'
$global:defaultPassword = 'admin@2'
$global:sqlUser = 'sa'
$global:sqlPass = 'admin@2'

# when issuing the command to craete new project you could interate using tab key through these branches after specifiying the -predefinedBranches switch
$global:predefinedBranches = @("$/CMS/Sitefinity 4.0/Code Base",
"$/CMS/Sitefinity 4.0/TeamBranches/U3/Code Base")

# Projects have integer as ids. They will be prefixed with the string specified here.
$global:idPrefix = "sf"