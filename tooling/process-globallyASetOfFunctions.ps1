# $path = "$PSScriptRoot\..\sf-dev\core"
$path = "$PSScriptRoot\..\tests"

# $oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames = @('RemoveProjectData','SetProjectData','SetDefaultTagsFilter','GetDefaultTagsFilter','InitManagerData','NewSfProjectObject','GetAzureDevOpsTitleAndLink','GetValidTitle','CreateUserFriendlySlnName','SaveSelectedProject','ValidateProject','GetIsIdDuplicate','IsDuplicate','GenerateId','SetConsoleTitle','GenerateSolutionFriendlyName','ValidateNameSyntax','CreateWorkspace','InitializeProject','aliuty','CreateProjectFilesFromSource','ValidateTag','FilterProjectsByTags','CheckIfTagged','GetDaysSinceLastGetLatest','PromptPredefinedBranchSelect','PromptPredefinedBuildPathSelect','PromptProjectSelect','ExecuteBatchBlock','ShouldClean','AddError','UpdateLastGetLatest','GetLastWorkspaceChangesetDate','BuildProj','SwitchStyleCop','WriteFile','GetAppUrl','GenerateDomainName','GetDevAppUrl','DeleteWebsite','ChangeDomain','GetCurrentAppDbName','GetDataConfig','StartApp','InvokeNonTerminatingRequest','DeleteStartupConfig','CreateStartupConfig','ResetAppDataFiles','CleanSfRuntimeFiles','CopySfRuntimeFiles','RestoreSfRuntimeFiles','SelectAppState','GetSqlBackupStateName','GetSqlCredentials','GetStatesPath')

function Rename-Function {
    param (
        [string]$text
    )
    
    $text = $text.Replace("_", "");
    $result = "";
    $setCapital = $true;
    for ($i = 0; $i -lt $text.Length; $i++) {
        $letter = $text[$i]
        if ($setCapital) {
            $newResult = $letter.ToString().ToUpperInvariant();
        } else {
            $newResult = $letter
        }

        if ($letter -eq '-') {
            $setCapital = $true;
        } else {
            $result = "$result$newResult"
            $setCapital = $false;
        }
    }

    $result
}

$scripts = Get-ChildItem $path -Recurse | Where-Object { $_.Extension -eq '.ps1'}

$scripts | % { 
    $content = Get-Content $_.FullName
    $oldNames | % {
        # $newTitle = Rename-Function($_)
        $oldName = [string]$_
        $newTitle = "_" + ($oldName[0]).ToString().ToLowerInvariant() + $oldName.Remove(0, 1)
        $content = $content -replace $oldName, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
