$global:testProjectResourcePath = "$PSScriptRoot\..\utils\files\test-project"
$global:testProjectDbName = "testsDb"
$global:testProjectPreviousProjectsDirectory
$global:testProjectPreviousToolDataPath

function global:InTestProjectScope ([ScriptBlock]$its) {
    New-TestProject
    try {
        & $its
    }
    finally {
        Remove-TestProject
    }
}

function global:New-TestProject {
    $Global:appPath = "$env:TEMP\$([Guid]::NewGuid().ToString())"
    New-Item $appPath -ItemType Directory
    $global:testProjectPreviousProjectsDirectory = $GLOBAL:sf.config.projectsDirectory
    $GLOBAL:sf.config.projectsDirectory = "$appPath\projects"
    $global:testProjectPreviousToolDataPath = $GLOBAL:sf.config.dataPath
    $GLOBAL:sf.config.dataPath = "$appPath\TEMP.xml"
    _initManagerData

    $id = "$($sf.config.idPrefix)$([Guid]::NewGuid().ToString().Split('-')[0])"
    [SfProject]$sourceProj = _newSfProjectObject -id $id
    $solutionPath = "$($GLOBAL:sf.config.projectsDirectory)\$id"
    $webAppPath = "$solutionPath\SitefinityWebApp"

    $sourceProj.displayName = "test_proj"
    $sourceProj.solutionPath = $solutionPath
    $sourceProj.webAppPath = $webAppPath
    $sourceProj.websiteName = $id

    New-Item -Path $solutionPath -ItemType Directory -ErrorAction SilentlyContinue
    Copy-Item -Path "$global:testProjectResourcePath\*" -Destination $solutionPath -Recurse -Force -ErrorAction Stop
   
    New-WebAppPool -Name $sourceProj.websiteName
    $port = iis-getFreePort
    New-Website -Name $sourceProj.websiteName -PhysicalPath $sourceProj.webAppPath -Port $port -ApplicationPool $sourceProj.websiteName

    sf-project-save -context $sourceProj

    $sourceProj = (sf-project-getAll)[0]
    # $sourceProj.isInitialized = $true
    sf-project-setCurrent $sourceProj

    sql-createDb -dbName $global:testProjectDbName
}

function global:Remove-TestProject {
    Set-Location $GLOBAL:PSHOME
    $idFilter = "$($global:sf.config.idPrefix)*"

    if (Test-Path $Global:appPath) {
        Remove-Item $Global:appPath -Force -Recurse
    }
    
    Get-Website | ? Name -like $idFilter | Remove-Website
    # do not use get-iisapppool - does not return latest
    Get-ChildItem "IIS:\AppPools" | ? Name -like $idFilter | Remove-WebAppPool
    sql-get-dbs | ? name -like $idFilter | % { sql-delete-database $_.name }
    sql-delete-database -dbName $global:testProjectDbName
    Remove-Item "$(_nginx-getToolsConfigDirPath)\*.$global:nlbClusterConfigExtension"

    $GLOBAL:sf.config.projectsDirectory = $global:testProjectPreviousProjectsDirectory
    $GLOBAL:sf.config.dataPath = $global:testProjectPreviousToolDataPath
}