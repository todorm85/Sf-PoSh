$appPath = (Get-PSDrive TestDrive).Root
$id = (@([Guid]::NewGuid().ToString().Split('-'))[0])
[SfProject]$sourceProj = _newSfProjectObject -id $id
$solutionPath = "$appPath\$id"
$webAppPath = "$solutionPath\SitefinityWebApp"
New-Item -Path $solutionPath -ItemType Directory -ErrorAction SilentlyContinue
Copy-Item -Path "$PSScriptRoot\..\utils\files\test-project\*" -Destination $solutionPath -Recurse -Force -ErrorAction Stop

$sourceProj.displayName = "test-proj"
$sourceProj.solutionPath = $solutionPath
$sourceProj.webAppPath = $webAppPath
$sourceProj.websiteName = $id
Remove-Website -Name $sourceProj.websiteName -ErrorAction SilentlyContinue -Confirm:$false
$port = _getFreePort
New-Website -Name $sourceProj.websiteName -PhysicalPath $sourceProj.webAppPath -Port $port

$sourceProj.isInitialized = $true
sd-project-save -context $sourceProj
sd-project-setCurrent $sourceProj
$Global:testProject = $sourceProj

sql-delete-database -dbName "testsDb"
sql-createDb -dbName "testsDb"
