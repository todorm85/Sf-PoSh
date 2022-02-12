Set-Alias -Name prn -Value sf-project-rename
Set-Alias -Name pgc -Value sf-project-get
Set-Alias -Name prm -Value sf-project-remove
Set-Alias -Name prmb -Value sf-project-removeBulk
Set-Alias -Name s -Value sf-project-select
Set-Alias -Name pga -Value sf-project-getAll

Set-Alias -Name ta -Value sf-project-tags-add
Set-Alias -Name tr -Value sf-project-tags-remove
Set-Alias -Name tg -Value sf-project-tags-get

Set-Alias -Name res -Value sf-iis-AppPool-Reset
Set-Alias -Name b -Value sf-iis-Site-browse

Set-Alias -Name asg -Value sf-States-get
Set-Alias -Name ass -Value sf-States-save
Set-Alias -Name asrs -Value sf-States-restore
Set-Alias -Name asrm -Value sf-States-remove

Set-Alias -Name gt -Value sf-paths-goto
Set-Alias -Name sw -Value sfe-startWebTestRunner
Set-Alias -Name rei -Value sf-app-reinitialize
Set-Alias -Name o -Value sf-sol-open
Set-Alias -Name ch -Value git-checkout

# module dev shortcuts
Set-Alias -Name deploy -Value sf-module-copyDevToLive
Set-Alias -Name test -Value sf-module-runTests
Set-Alias -Name re -Value sf-module-import
Set-Alias -Name pub -Value sf-module-publish

function sf-aliases-open {
    ii $PSCommandPath
}