. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Test cloning project should" {
        $sourceProj = Set-TestProject

        $sourceName = $sourceProj.displayName
        $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here
        
        sf-data-getAllProjects | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sf-proj-remove -noPrompt -context $_
        }
        
        $GLOBAL:Sf.sql.GetDbs() | Where-Object { $_.name -eq $sourceProj.id } | Should -HaveCount 1

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

        sf-proj-clone

        [SfProject]$project = sf-proj-getCurrent
        $cloneTestId = $project.id

        It "set project displayName" {
            $project.displayName | Should -Be $cloneTestName
        }
        
        It "set project branch" {
            $project.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
        }

        It "set project solution path" {
            $project.solutionPath.Contains($GLOBAL:Sf.Config.projectsDirectory) | Should -Be $true
        }

        It "set project site" {
            $project.websiteName | Should -Be $cloneTestId
        }
    
        It "create project solution directory" {
            Test-Path $project.solutionPath | Should -Be $true
        }

        It "create a hosts file entry" {
            existsInHostsFile -searchParam $project.displayName | Should -Be $true
        }

        It "create a user friendly solution name" {
            Test-Path "$($project.solutionPath)\$($project.displayName)($($project.id)).sln" | Should -Be $true
        }

        It "copy the original solution file" {
            Test-Path "$($project.solutionPath)\Telerik.Sitefinity.sln" | Should -Be $true
        }

        It "create website pool" {
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
        }

        It "create website" {
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
        }

        It "create a copy of db" {
            $GLOBAL:Sf.sql.GetDbs() | Where-Object { $_.name -eq $cloneTestId } | Should -HaveCount 1
        }
    }
}