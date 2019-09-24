<#
.SYNOPSIS
    Cleans all project artefacts in case a project was not deleted successfuly - deletes websites, databases, host file mappings based on a search
    using the id prefix and checking whether a project in the tools database still exist or has been removed from the tool.
#>
function sf-clean-allProjectsLeftovers {
    $projectsDir = $GLOBAL:Sf.Config.projectsDirectory
    $idsInUse = sf-get-allProjects | ForEach-Object { $_.id }
    
    function shouldClean {
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
    function _add-error ($text) {
        $errors = "$errors$text`n"
    }

    try {
        Write-Information "Sites cleanup"
        Import-Module WebAdministration
        $sites = Get-Item "IIS:\Sites" 
        $names = $sites.Children.Keys | Where-Object { shouldClean $_ }
        
        foreach ($site in $names) {
            Remove-Item "IIS:\Sites\$($site)" -Force -Recurse
        }
    }
    catch {
        _add-error "Sites were not cleaned up: $_"
    }

    try {
        Write-Information "App pool cleanup"
        Import-Module WebAdministration
        $pools = Get-Item "IIS:\AppPools" 
        $names = $pools.Children.Keys | Where-Object { shouldClean $_ }
        foreach ($poolName in $names) {
            Remove-Item "IIS:\AppPools\$($poolName)" -Force -Recurse
        }
    }
    catch {
        _add-error "Application pools were not cleaned up: $_"
    }

    try {
        Write-Information "TFS cleanup"
        $wss = tfs-get-workspaces $GLOBAL:Sf.Config.tfsServerName
        $wss | Where-Object { shouldClean $_ } | ForEach-Object { tfs-delete-workspace $_ $GLOBAL:Sf.Config.tfsServerName }
    }
    catch {
        _add-error "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Information "DBs cleanup"
        
        $dbs = $tokoAdmin.sql.GetDbs()
        $dbs | Where-Object { $_.name.StartsWith("$($GLOBAL:Sf.Config.idPrefix)") -and (shouldClean $_.name) } | ForEach-Object {
            $tokoAdmin.sql.Delete($_.name)
        }
    }
    catch {
        _add-error "Databases were not cleaned up: $_"
    }

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Information "Projects directory cleanup"
        unlock-allFiles $projectsDir
        Get-ChildItem $projectsDir | Where-Object { shouldClean $_.Name } | % { Remove-Item $_.FullName -Force -Recurse }
    }
    catch {
        _add-error "Test sitefinities were not cleaned up: $_"
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
function sf-goto {
    
    Param(
        [switch]$configs,
        [switch]$logs,
        [switch]$root,
        [switch]$webConfig
    )

    $context = sf-get-currentProject
    $webAppPath = $context.webAppPath

    if ($configs) {
        cd "${webAppPath}\App_Data\Sitefinity\Configuration"
        ls
    }
    elseif ($logs) {
        cd "${webAppPath}\App_Data\Sitefinity\Logs"
        ls
    }
    elseif ($root) {
        cd "${webAppPath}"
        ls
    }
    elseif ($webConfig) {
        & "${webAppPath}\Web.config"
    }
}
