# project
Set-Alias -Name prn -Value sf-project-rename
Set-Alias -Name pg -Value sf-project-get
Set-Alias -Name prm -Value sf-project-remove
Set-Alias -Name prmb -Value sf-project-removeBulk
Set-Alias -Name s -Value sf-project-select

# tags
Set-Alias -Name ta -Value sf-project-tags-add
Set-Alias -Name tr -Value sf-project-tags-remove
Set-Alias -Name tg -Value sf-project-tags-get

# site
Set-Alias -Name re -Value sf-iis-AppPool-Reset
Set-Alias -Name b -Value sf-iis-Site-browse

# states
Set-Alias -Name sg -Value sf-States-get
Set-Alias -Name ss -Value sf-States-save
Set-Alias -Name sr -Value sf-States-restore
Set-Alias -Name srm -Value sf-States-remove

# sol
Set-Alias -Name gt -Value sf-paths-goto
Set-Alias -Name o -Value sf-sol-open
Set-Alias -Name sb -Value sf-sol-build

# app
Set-Alias -Name ar -Value sf-app-reinitialize
Set-Alias -Name ae -Value sf-app-ensureRunning

# test runner
Set-Alias -Name sw -Value sfe-startWebTestRunner

# git
Set-Alias -Name ch -Value git-checkout

# nlb
Set-Alias -Name oa -Value sf-nlb-overrideOtherNodeConfigs

# module
Set-Alias -Name deploy -Value sf-module-copyDevToLive
Set-Alias -Name test -Value sf-module-runTests
Set-Alias -Name reload -Value sf-module-import
Set-Alias -Name pub -Value sf-module-publish

function ree {
    sf-iis-AppPool-Reset
    sf-app-ensureRunning
}

function sf-aliases-open {
    ii $PSCommandPath
}