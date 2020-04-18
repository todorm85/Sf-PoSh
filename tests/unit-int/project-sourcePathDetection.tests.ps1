. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    . "${PSScriptRoot}\init.ps1"

    Describe "_createAndDetectProjectArtifactsFromSourcePath should" {
        $GLOBAL:sf.Config.projectsDirectory = "$TestDrive"
        $appNoSolutionZipPath = "$PSScriptRoot\..\utils\files\Build\SitefinityWebApp.zip"
        $appWithSolutionZipPath = "$PSScriptRoot\..\utils\files\Build\SitefinitySource.zip"
        It "Create files from archive when path to zip with no solution" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id $id
            _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath $appNoSolutionZipPath
            $project.webAppPath | Should -Be "$TestDrive\$id"
            $project.solutionPath | Should -BeNullOrEmpty
        }
        It "Create files from archive when path to zip with solution" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id $id
            _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath $appWithSolutionZipPath
            $project.webAppPath | Should -Be "$TestDrive\$id\SitefinityWebApp"
            $project.solutionPath | Should -Be "$TestDrive\$id"
        }
        It "throw when no zip found" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id $id
            { _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath "$TestDrive/nonexisting.zip" } | Should -Throw -ExpectedMessage "Source path does not exist"
        }
        It "throw when no folder found" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id $id
            { _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath "$TestDrive/nonexisting" } | Should -Throw -ExpectedMessage "Source path does not exist"
        }
        It "create from source when branch supplied" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id "$id"
            $branchPath = "$/CMS/dummy"
            Mock _createWorkspace {
                $branch | Should -Be $branchPath
            }

            _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath $branchPath
            $project.solutionPath | Should -Be "$($TestDrive)\$id"
            $project.webAppPath | Should -Be "$($TestDrive)\$id\SitefinityWebApp"
        }
    }
}