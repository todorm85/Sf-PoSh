Param($destination = "C:\sf-dev")

Write-Host "Deploying..."

# . "$PSScriptRoot\manifest-generator.ps1"

$filtered = @('db.xml', 'config.user.ps1')

Get-ChildItem $destination |
    Where-Object { -not $filtered.Contains($_.Name) } |
    Remove-Item -Force -Recurse

Get-ChildItem -Path "$PSScriptRoot\module" |
    Where-Object { -not $filtered.Contains($_.Name) } |
    Copy-Item -Destination $destination -Recurse
