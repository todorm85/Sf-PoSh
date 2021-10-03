. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

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
        It "create from source when supplied" {
            $id = generateRandomName
            [SfProject]$project = _newSfProjectObject -id "$id"
            Mock sf-source-new {
                New-Item -Path "$localPath\$directoryName" -ItemType Directory -Force
            }

            _createAndDetectProjectArtifactsFromSourcePath -project $project -sourcePath "https://prgs-sitefinity.visualstudio.com/Sitefinity/_git/sitefinity"
            $project.solutionPath | Should -Be "$($TestDrive)\$id"
            $project.webAppPath | Should -Be "$($TestDrive)\$id\SitefinityWebApp"
        }
    }
}