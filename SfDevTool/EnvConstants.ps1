# Environment Constants

# the path where provisioned sitefinity projects by the script will be used.
$projectsDirectory = "D:\sitefinities"

# the sql server name that you use to connect to sql server. This db server will be used to created provisioned sitefinity dbs
$sqlServerInstance = '.'

# browser used to launch web apps by the script
$browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

# path to visual studio used to launch projects from the script
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

# msbuild used by the script to build projects
$msBUildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"

# used for tfs workspace manipulations, installed with Visual Studio
$tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe"

# needed if you use precompiled templates functions can be found at $/CMS/Sitefinity 4.0/Tools/Telerik.WebTestRunner
$sitefinityCompiler = "D:\Tools\SitefinityCompiler\SitefinityCompiler\bin\Release\Telerik.Sitefinity.Compiler.exe" 

# the path to webtestrunner used to run integration tests
$WebTestRunner = "D:\Tools\Telerik.WebTestRunner\Telerik.WebTestRunner.Client\bin\Debug\Telerik.WebTestRunner.Client.exe"