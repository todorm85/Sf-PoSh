. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    It "Test cloning project" {
        $sourceProj = Set-TestProject

        $sourceName = $sourceProj.displayName
        $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here
        
        sf-data-getAllProjects | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sf-proj-remove -noPrompt -context $_
        }
        
        $tokoAdmin.sql.GetDbs() | Where-Object { $_.name -eq $sourceProj.id } | Should -HaveCount 1

        # edit a file in source project and mark as changed in TFS
        $webConfigPath = "$($sourceProj.webAppPath)\web.config"
        tfs-checkout-file $webConfigPath > $null
        [xml]$xmlData = Get-Content $webConfigPath
        [System.Xml.XmlElement]$appSettings = $xmlData.configuration.appSettings
        $newElement = $xmlData.CreateElement("add")
        $testKeyName = generateRandomName
        $newElement.SetAttribute("key", $testKeyName)
        $newElement.SetAttribute("value", "testing")
        $appSettings.AppendChild($newElement)
        $xmlData.Save($webConfigPath) > $null

        sf-proj-clone -context $sourceProj

        # verify project configuration
        [SfProject]$project = sf-proj-getCurrent
        $project.displayName | Should -Be $cloneTestName
        $cloneTestId = $project.id
        $project.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
        # tfs-get-branchPath -path $project.solutionPath | Should -Not -Be $null
        $project.solutionPath.Contains($GLOBAL:Sf.Config.projectsDirectory) | Should -Be $true
        $project.websiteName | Should -Be $cloneTestId
    
        # verify project artifacts
        Test-Path $project.solutionPath | Should -Be $true
        existsInHostsFile -searchParam $project.displayName | Should -Be $true
        Test-Path "$($project.solutionPath)\$($project.displayName)($($project.id)).sln" | Should -Be $true
        Test-Path "$($project.solutionPath)\Telerik.Sitefinity.sln" | Should -Be $true
        Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
        Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
        $tokoAdmin.sql.GetDbs() | Where-Object { $_.name -eq $cloneTestId } | Should -HaveCount 1
    }
}