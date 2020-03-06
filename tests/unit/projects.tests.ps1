. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    . "${PSScriptRoot}\..\test-utils\test-util.ps1"

    Describe "_createAndDetectProjectArtifactsFromSourcePath should" {
        $GLOBAL:sf.Config.projectsDirectory = "$TestDrive"
        Copy-Item -Path "$PSScriptRoot\..\test-utils\files\Build\SitefinityWebApp.zip" -Destination "$TestDrive"
        $appNoSolutionZipPath = "$TestDrive\SitefinityWebApp.zip"
        Copy-Item -Path "$PSScriptRoot\..\test-utils\files\Build\SitefinitySource.zip" -Destination "$TestDrive"
        $appWithSolutionZipPath = "$TestDrive\SitefinitySource.zip"

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

            $project.webAppPath | Should -Be "$TestDrive\$id/SitefinityWebApp"
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