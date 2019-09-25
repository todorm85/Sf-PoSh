<#
.SYNOPSIS
    Cleans all project artefacts in case a project was not deleted successfuly - deletes websites, databases, host file mappings based on a search
    using the id prefix and checking whether a project in the tools database still exist or has been removed from the tool.
#>
function Clear-AllProjectsLeftovers {
    $projectsDir = $GLOBAL:Sf.Config.projectsDirectory
    $idsInUse = Get-AllProjects | ForEach-Object { $_.id }
    
    function ShouldClean {
        param (
            $id
        )

        if (-not ($id -match "$($GLOBAL:Sf.Config.idPrefix)\d+")) {
            return $false
        }
        
        if (-not $idsInUse.Contains($id)) {
            return $true
        }
    
        return $false
    }

    $errors = ''
    function AddError ($text) {
        $errors = "$errors$text`n"
    }

    try {
        Write-Information "Sites cleanup"
        Import-Module WebAdministration
        $sites = Get-Item "IIS:\Sites" 
        $names = $sites.Children.Keys | Where-Object { ShouldClean $_ }
        
        foreach ($site in $names) {
            Remove-Item "IIS:\Sites\$($site)" -Force -Recurse
        }
    }
    catch {
        AddError "Sites were not cleaned up: $_"
    }

    try {
        Write-Information "App pool cleanup"
        Import-Module WebAdministration
        $pools = Get-Item "IIS:\AppPools" 
        $names = $pools.Children.Keys | Where-Object { ShouldClean $_ }
        foreach ($poolName in $names) {
            Remove-Item "IIS:\AppPools\$($poolName)" -Force -Recurse
        }
    }
    catch {
        AddError "Application pools were not cleaned up: $_"
    }

    try {
        Write-Information "TFS cleanup"
        $wss = tfs-get-workspaces $GLOBAL:Sf.Config.tfsServerName
        $wss | Where-Object { ShouldClean $_ } | ForEach-Object { tfs-delete-workspace $_ $GLOBAL:Sf.Config.tfsServerName }
    }
    catch {
        AddError "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Information "DBs cleanup"
        
        $dbs = $tokoAdmin.sql.GetDbs()
        $dbs | Where-Object { $_.name.StartsWith("$($GLOBAL:Sf.Config.idPrefix)") -and (ShouldClean $_.name) } | ForEach-Object {
            $tokoAdmin.sql.Delete($_.name)
        }
    }
    catch {
        AddError "Databases were not cleaned up: $_"
    }

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Information "Projects directory cleanup"
        unlock-allFiles $projectsDir
        Get-ChildItem $projectsDir | Where-Object { ShouldClean $_.Name } | ForEach-Object { Remove-Item $_.FullName -Force -Recurse }
    }
    catch {
        AddError "Test sitefinities were not cleaned up: $_"
    }

    if ($errors) {
        throw $errors
    }
}

<#
    .SYNOPSIS
    Quick naviagtion in project directories. Sets the console working directory.
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function Goto {
    
    Param(
        [switch]$configs,
        [switch]$logs,
        [switch]$root,
        [switch]$webConfig
    )

    $context = Get-CurrentProject
    $webAppPath = $context.webAppPath

    if ($configs) {
        Set-Location "${webAppPath}\App_Data\Sitefinity\Configuration"
        Get-ChildItem
    }
    elseif ($logs) {
        Set-Location "${webAppPath}\App_Data\Sitefinity\Logs"
        Get-ChildItem
    }
    elseif ($root) {
        Set-Location "${webAppPath}"
        Get-ChildItem
    }
    elseif ($webConfig) {
        & "${webAppPath}\Web.config"
    }
}
