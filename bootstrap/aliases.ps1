# project
Set-Alias -Name prn -Value sf-project-rename -Scope global
Set-Alias -Name pg -Value sf-project-get -Scope global
Set-Alias -Name prm -Value sf-project-remove -Scope global
Set-Alias -Name prmb -Value sf-project-removeBulk -Scope global
Set-Alias -Name s -Value sf-project-select -Scope global

# tags
Set-Alias -Name ta -Value sf-project-tags-add -Scope global
Set-Alias -Name tr -Value sf-project-tags-remove -Scope global
Set-Alias -Name tg -Value sf-project-tags-get -Scope global

# site
Set-Alias -Name re -Value sf-iis-AppPool-Reset -Scope global
Set-Alias -Name b -Value sf-iis-Site-browse -Scope global

# states
Set-Alias -Name sg -Value sf-States-get -Scope global
Set-Alias -Name ss -Value sf-States-save -Scope global
Set-Alias -Name sr -Value sf-States-restore -Scope global
Set-Alias -Name srm -Value sf-States-remove -Scope global

# sol
Set-Alias -Name gt -Value sf-paths-goto -Scope global
Set-Alias -Name o -Value sf-sol-open -Scope global
Set-Alias -Name sb -Value sf-sol-build -Scope global

# app
Set-Alias -Name ar -Value sf-app-reinitialize -Scope global
Set-Alias -Name ae -Value sf-app-ensureRunning -Scope global

# test runner
Set-Alias -Name sw -Value sfe-startWebTestRunner -Scope global

# git
Set-Alias -Name ch -Value sf-git-checkout -Scope global

# nlb
Set-Alias -Name oa -Value sf-nlb-overrideOtherNodeConfigs -Scope global

# module
Set-Alias -Name deploy -Value sf-module-copyDevToLive -Scope global
Set-Alias -Name test -Value sf-module-runTests -Scope global
Set-Alias -Name reload -Value sf-module-import -Scope global
Set-Alias -Name pub -Value sf-module-publish -Scope global

function ree {
    sf-iis-AppPool-Reset
    sf-app-ensureRunning
}

function sf-aliases-open {
    ii $PSCommandPath
}