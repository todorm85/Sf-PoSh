Param($destination = "C:\sf-dev")

$answer = $null
while ($answer -ne 'y') {
    $answer = Read-Host -Prompt "Are you sure you want to deploy sf-dev to live? y/n"
}

Write-Host "Deploying..."

& "$PSScriptRoot\new-manifest.ps1"

$filtered = @('db.xml', 'config.user.ps1')

Get-ChildItem $destination |
    Where-Object { -not $filtered.Contains($_.Name) } |
    Remove-Item -Force -Recurse

Get-ChildItem -Path "$PSScriptRoot\..\module" |
    Where-Object { -not $filtered.Contains($_.Name) } |
    Copy-Item -Destination $destination -Recurse

& "$PSScriptRoot\new-manifest.ps1" dev
