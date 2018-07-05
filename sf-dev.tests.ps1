Import-Module sf-dev

InModuleScope sf-dev {
    $Script:dataPath = "${PSScriptRoot}\test-db.xml"
    $Script:projectsDirectory = "e:\sitefinities\tests"
    if (-not (Test-Path $Script:projectsDirectory)) {
        New-Item $Script:projectsDirectory -ItemType Directory
    }

    init-managerData
    $baseTestId = 'test_instance_'
    Mock _generateId {
        $i = 0;
        while ($true) {
            $name = "${baseTestId}${i}"
            $isDuplicate = (_get-isNameDuplicate $name)
            if (-not $isDuplicate) {
                break;
            }
            
            $i++
        }

        return $name
    }
    
    function cleanup () {
        Write-Host "Tests cleanup"
        Write-Host "Resetting IIS..."
        iisreset.exe

        try {
            Write-Host "Sites cleanup"
            Get-IISSite| Where-Object {$_.Name.StartsWith('test_') } | Remove-IISSite -Confirm:$false -ErrorAction "Stop"
        }
        catch {
            Write-Warning "Sites were not cleaned up: $_"
        }

        try {
            Write-Host "App pool cleanup"
            Get-IISAppPool | Where-Object {$_.Name.StartsWith('test_') } | Remove-WebAppPool -Confirm:$false -ErrorAction "Stop"
        }
        catch {
            Write-Warning "Application pools were not cleaned up: $_"
        }

        try {
            Write-Host "SQL logins cleanup"
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $allLogins = $sqlServer.Logins | Where-Object {$_.Name.Contains('test_')}
            $allLogins | ForEach-Object {$_.Drop()}
        }
        catch {
            Write-Warning "SQL logins were not cleaned up: $_"
        }

        try {
            Write-Host "Domain mapping cleanup"
            Show-Domains | Where-Object {$_.Contains('test_instance')} | ForEach-Object {$_.Split(' ')[0]} | ForEach-Object {Remove-Domain $_}
        }
        catch {
            Write-Warning "SQL logins were not cleaned up: $_"
        }

        try {
            Write-Host "TFS cleanup"
            $wss = tfs-get-workspaces 
            $wss | Where-Object {$_.StartsWith('test_') } | ForEach-Object { tfs-delete-workspace $_ }
        }
        catch {
            Write-Warning "Tfs workspaces were not cleaned up: $_"
        }

        try {
            Write-Host "DBs cleanup"
            $dbs = sql-get-dbs 
            $dbs | Where-Object {$_.name.StartsWith('test_') } | ForEach-Object { sql-delete-database $_ }
        }
        catch {
            Write-Warning "Databases were not cleaned up: $_"
        }

        try {
            Write-Host "Module db cleanup"
            Remove-Item $Script:dataPath
        }
        catch {
            Write-Warning "Module db file was not cleaned up: $_"
        }

        try {
            Set-Location -Path $PSHOME
            sleep.exe 5
            Write-Host "Projects directory cleanup"
            Remove-Item $Script:projectsDirectory -Force -Recurse
        }
        catch {
            Write-Warning "Test sitefinities were not cleaned up: $_"
        }
    }

    Describe "sf-dev should" {
        
        It "cleanup" {
            cleanup
        }

        It "create project correctly" {
            sf-new-project -displayName 'test1' -predefinedBranch '$/CMS/Sitefinity 4.0/Code Base'
            $sitefinities = @(_sfData-get-allProjects)
            $sitefinities | Should -HaveCount 1
            $testId = "${baseTestId}0"
            $sf = $sitefinities[0]
            $sf.name | Should -Be "${testId}"
            $sf.displayName | Should -Be 'test1'
            $sf.containerName | Should -Be ''
            Test-Path "$($Script:projectsDirectory)\${testId}\$($sf.displayName)($($sf.name)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${testId}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $true
            Test-Path "IIS:\Sites\${testId}" | Should -Be $true
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 1
        }

        It "build and start Sitefinity" {
            sf-build-solution
            _sf-create-startupConfig
            _sf-start-app
            $url = _sf-get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }

        It "delete project correctly" {
            # sf-delete-project
        }

        It "cleanup" {
            cleanup
        }
    }

}
