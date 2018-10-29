Param(
    $idPref = "sf_tests_",
    $projectsDir = "e:\dev-sitefinities\tests",
    $dataPath = "$projectsDir\test-db.xml"
)

$xml = New-Object XML
$xml.Load($dataPath)
$idsInUse = @($xml.data.sitefinities.sitefinity.id)
Get-ChildItem -Path "E:\sf-dev\module\core\infrastructure" -Filter '*.ps1' -Recurse | % {. $_.FullName}

function shouldClean {
    param (
        $id
    )

    if ($id.Contains($idPref) -and (-not $idsInUse.Contains($id))) {
        return $true
    }
    
    return $false
}

iisreset.exe
try {
    Get-Process msbuild -ErrorAction Stop | Stop-Process -ErrorAction Stop
}
catch {
    "No msbuild processes to clean."    
}

try {
    Write-Host "Sites cleanup"
    _iis-load-webAdministrationModule
    $sites = Get-Item "IIS:\Sites" 
    $names = $sites.Children.Keys | Where-Object { shouldClean($_) }
        
    foreach ($site in $names) {
        Remove-Item "IIS:\Sites\$($site)" -Force -Recurse
    }
}
catch {
    Write-Warning "Sites were not cleaned up: $_"
}

try {
    Write-Host "App pool cleanup"
    $pools = Get-Item "IIS:\AppPools" 
    $names = $pools.Children.Keys | Where-Object { shouldClean($_) }
    foreach ($poolName in $names) {
        Remove-Item "IIS:\AppPools\$($poolName)" -Force -Recurse
    }
}
catch {
    Write-Warning "Application pools were not cleaned up: $_"
}

try {
    Write-Host "SQL logins cleanup"
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
    $allLogins = $sqlServer.Logins | Where-Object { shouldClean($_.Name) }
    $allLogins | ForEach-Object {$_.Drop()}
}
catch {
    Write-Warning "SQL logins were not cleaned up: $_"
}

try {
    Write-Host "Domain mapping cleanup"
    Show-Domains | Where-Object { shouldClean($_) } | ForEach-Object { $_.Split(' ')[0] } | ForEach-Object { Remove-Domain $_ }
}
catch {
    Write-Warning "Domains were not cleaned up: $_"
}

try {
    Write-Host "TFS cleanup"
    $wss = tfs-get-workspaces 
    $wss | Where-Object { shouldClean($_) } | ForEach-Object { tfs-delete-workspace $_ }
}
catch {
    Write-Warning "Tfs workspaces were not cleaned up: $_"
}

try {
    Write-Host "DBs cleanup"
    $dbs = sql-get-dbs 
    $dbs | Where-Object { shouldClean($_.name) } | ForEach-Object { sql-delete-database $_.name }
}
catch {
    Write-Warning "Databases were not cleaned up: $_"
}

try {
    Set-Location -Path $PSHOME
    sleep.exe 5
    Write-Host "Projects directory cleanup"
    Get-ChildItem $projectsDir | where { shouldClean($_.Name) } | % { Remove-Item $_.FullName -Force -Recurse }
}
catch {
    Write-Warning "Test sitefinities were not cleaned up: $_"
}