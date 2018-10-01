Param($destination = "$($ENV:USERPROFILE)\Documents\WindowsPowerShell\Modules\sf-dev")

Write-Host "Deploying..."

# . "$PSScriptRoot\manifest-generator.ps1"

$filtered = @('db.xml', 'config.ps1')

Get-ChildItem $destination |
    where { -not $filtered.Contains($_.Name) } |
    Remove-Item -Force -Recurse

Get-ChildItem -Path "$PSScriptRoot\module" |
    where { -not $filtered.Contains($_.Name) } |
    Copy-Item -Destination $destination -Recurse
