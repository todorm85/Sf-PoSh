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
Remove-WebAppPool -Name $sourceProj.websiteName -ErrorAction SilentlyContinue -Confirm:$false
$port = sd-getFreePort
New-WebAppPool -Name $sourceProj.websiteName
New-Website -Name $sourceProj.websiteName -PhysicalPath $sourceProj.webAppPath -Port $port -ApplicationPool $sourceProj.websiteName

$sourceProj.isInitialized = $true
sd-project-save -context $sourceProj

$sourceProj = (sd-project-getAll)[0]
sd-project-setCurrent $sourceProj
$Global:testProjectWebsiteName = $id

sql-delete-database -dbName "testsDb"
sql-createDb -dbName "testsDb"
