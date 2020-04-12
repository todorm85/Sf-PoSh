. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Subapp functionality should" -Tags ("subapp") {
        . "$PSScriptRoot\test-project-init.ps1"

        [SfProject]$project = sf-project-getCurrent
        $subApp = "subApp"
        $site = $project.websiteName
        $pool = (Get-Website -Name $site).applicationPool

        It "create application and set its path and app pool" {
            sf-iisSubApp-set -subAppName $subApp
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $true
            (Get-Item -Path "IIS:\Sites\$site\$subApp").applicationPool | Should -Be $pool
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Not -Be $project.webAppPath
        }
        It "return the correct url for subapp" {
            $res = sf-iisSite-getUrl
            $res.EndsWith($subApp) | Should -Be $true
        }
        It "remove sub app by deleting the application and setting the site path" {
            sf-iisSubApp-remove
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $false
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Be $project.webAppPath
        }
        It "build the correct url after subapp removal" {
            $res = sf-iisSite-getUrl
            $res.EndsWith($subApp) | Should -Not -Be $true
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}
