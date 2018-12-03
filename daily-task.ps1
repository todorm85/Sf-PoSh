& "$PSScriptRoot\sf-dev-profile.ps1" prod
clear-nugetCache
sf-update-allProjectsTfsInfo
batchOverwriteProjectsWithLatestFromTfsIfNeeded