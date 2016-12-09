# Environment Constants

# the path where provisioned sitefinity projects by the script will be used.
$projectsDirectory = "D:\sitefinities"

if (-not Test-Path $projectsDirectory) {
    Write-Host "Projects directory not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs
$sqlServerInstance = '.'

# browser used to launch web apps by the script
$browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

if (-not Test-Path $browserPath) {
    Write-Host "Browser path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# path to visual studio used to launch projects from the script
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

if (-not Test-Path $vsPath) {
    Write-Host "Visual studio path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# msbuild used by the script to build projects
$msBUildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"

if (-not Test-Path $msBUildPath) {
    Write-Host "MSBuild path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# used for tfs workspace manipulations, installed with Visual Studio
$tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe"

if (-not Test-Path $tfPath) {
    Write-Host "Team foundation tool path not set in SfDevTool\EnvConstants.ps1 or it does not exist. (Used for tfs automation)"
}

# needed if you use precompiled templates functions can be found at $/CMS/Sitefinity 4.0/Tools/Telerik.WebTestRunner
$sitefinityCompiler = "D:\Tools\SitefinityCompiler\SitefinityCompiler\bin\Release\Telerik.Sitefinity.Compiler.exe"

# the path to webtestrunner used to run integration tests
$WebTestRunner = "D:\Tools\Telerik.WebTestRunner\Telerik.WebTestRunner.Client\bin\Debug\Telerik.WebTestRunner.Client.exe"