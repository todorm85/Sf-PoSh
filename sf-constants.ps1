# Environment Constants
$sqlServerInstance = '.' # the name of the local sql server instance that is used to connect
$browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"
$msBUildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"
$tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" # used for tfs workspace manipulations, installed with Visual Studio
$sitefinityCompiler = "D:\Tools\SitefinityCompiler\SitefinityCompiler\bin\Release\Telerik.Sitefinity.Compiler.exe" # needed if you use precompiled templates functions can be found at $/CMS/Sitefinity 4.0/Tools/Telerik.WebTestRunner
$WebTestRunner = "D:\Tools\Telerik.WebTestRunner\Telerik.WebTestRunner.Client\bin\ReleaseD:\Tools\Telerik.WebTestRunner\Telerik.WebTestRunner.Client\bin\Debug\Telerik.WebTestRunner.Client.exe"

# Sript constants
$scriptPath = $MyInvocation.ScriptName
$dataPath = "${PSScriptRoot}\sf-data.xml"

# Hardcoded settings

# Sitefinity web app
$defaultBranch = "$/CMS/Sitefinity 4.0/Code Base"
$webAppUser = 'admin'
$webAppUserPass = 'admin@2'

# DBP module
# testteam3test@mailinator.com
# admin@2

$dbpAccountId = "84500334-c148-4331-beae-60512c6eb9d8"
$dbpPort = 4080
$dbpEnv = "uat"