function Global:set-testProject {
    param(
        [Parameter(Mandatory = $true)]$appPath
    )

    $id = (@([Guid]::NewGuid().ToString().Split('-'))[0])
    [SfProject]$sourceProj = _newSfProjectObject -id $id
    $solutionPath = "$appPath\$id"
    $webAppPath = "$solutionPath\SitefinityWebApp"
    New-Item -Path $solutionPath -ItemType Directory -ErrorAction SilentlyContinue
    Copy-Item -Path "$PSScriptRoot\..\utils\files\test-project\*" -Destination $solutionPath -Recurse -Force -ErrorAction Stop

    $sourceProj.solutionPath = $solutionPath
    $sourceProj.webAppPath = $webAppPath
    $sourceProj.websiteName = $id
    Remove-Website -Name $sourceProj.websiteName -ErrorAction SilentlyContinue -Confirm:$false
    $port = _getFreePort
    New-Website -Name $sourceProj.websiteName -PhysicalPath $sourceProj.webAppPath -Port $port

    $sourceProj.isInitialized = $true
    sd-project-saveCurrent -context $sourceProj
    $Global:testProject = $sourceProj
}

function Global:clean-testProjectLeftovers {
    Set-Location $GLOBAL:PSHOME
    Remove-Website -Name $Global:testProject.websiteName -ErrorAction SilentlyContinue -Confirm:$false
}


if (!$Global:OnAfterConfigInit) { $Global:OnAfterConfigInit = @() }
$Global:OnAfterConfigInit += {
    $path = "$($GLOBAL:sf.Config.projectsDirectory)\data-tests-db.xml"
    $GLOBAL:sf.Config.dataPath = $path
    if (Test-Path $path) {
        Remove-Item $path -Force
    }

    $GLOBAL:sf.Config.idPrefix = "sfi"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"