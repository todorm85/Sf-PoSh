. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Subapp functionality should" -Tags ("subapp") {
        [SfProject]$project = set-testProject
        $subApp = "subApp"
        $site = $project.websiteName
        $pool = Get-IISSite -Name $site | Get-IISAppPool | Select-Object -ExpandProperty Name

        It "create application and set its path and app pool" {
            sd-iisSubApp-set -subAppName $subApp
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $true
            (Get-Item -Path "IIS:\Sites\$site\$subApp").applicationPool | Should -Be $pool
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Not -Be $project.webAppPath
        }
        It "return the correct url for subapp" {
            $res = sd-iisSite-getUrl
            $res.EndsWith($subApp) | Should -Be $true
        }
        It "remove sub app by deleting the application and setting the site path" {
            sd-iisSubApp-remove
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $false
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Be $project.webAppPath
        }
        It "build the correct url after subapp removal" {
            $res = sd-iisSite-getUrl
            $res.EndsWith($subApp) | Should -Not -Be $true
        }
    }
}
