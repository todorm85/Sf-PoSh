$latest = Get-ChildItem "$PSScriptRoot\dist" | Sort-Object -Property CreationTime -Descending | Select -First 1
if ($latest) {
    Import-Module "$($latest.FullName)\sf-posh.psd1" -Force
} else {
    . "$PSScriptRoot\load-module.ps1"
    Export-ModuleMember -Function *
}

