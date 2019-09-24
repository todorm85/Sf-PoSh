$oldNames = @('add-error', 'prompt-predefinedBranchSelect', 'prompt-predefinedBuildPathSelect', 'prompt-projectSelect', 'build-proj', 'write-File', 'get-appUrl', 'generate-domainName', 'get-devAppUrl', 'delete-website', 'change-domain', 'get-currentAppDbName', 'start-app', 'delete-startupConfig', 'create-startupConfig', 'reset-appDataFiles', 'clean-sfRuntimeFiles', 'copy-sfRuntimeFiles', 'restore-sfRuntimeFiles', 'select-appState', 'get-sqlBackupStateName', 'get-sqlCredentials', 'get-statesPath'
)

$scripts = Get-ChildItem "$PSScriptRoot\..\sf-dev\core" -Recurse | Where-Object { $_.Extension -eq '.ps1'}

$scripts | % { 
    $content = Get-Content $_.FullName
    $oldNames | % {
        $content = $content -replace $_, "_$_" 
    }

    $content | Set-Content -Path $_.FullName
}