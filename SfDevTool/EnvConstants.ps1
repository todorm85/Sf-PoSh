# Environment Constants

# the path where provisioned sitefinity projects by the script will be used.
$script:projectsDirectory = "D:\sitefinities"

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
$script:vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

if (-not (Test-Path $vsPath)) {
    throw "Visual studio path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# msbuild used by the script to build projects
$script:msBuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"

if (-not (Test-Path $msBuildPath)) {
    throw "MSBuild path not set in SfDevTool\EnvConstants.ps1 or it does not exist."
}

# used for tfs workspace manipulations, installed with Visual Studio
$script:tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe"

if (-not (Test-Path $tfPath)) {
    throw "Team foundation tool path not set in SfDevTool\EnvConstants.ps1 or it does not exist. (Used for tfs automation)"
}
