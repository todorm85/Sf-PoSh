. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "create from build location should" {
        $Global:sf.project.Create('test', '$/CMS/Sitefinity 4.0/Code Base')
        It "create site, add domain to hosts" {
            
        }
    }
}