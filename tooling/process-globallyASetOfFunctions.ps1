# $path = "$PSScriptRoot\..\sf-dev\core"
$path = "$PSScriptRoot\..\tests"

$oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames
return
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
        $newTitle = $_
        $newTitle = $newTitle + "_"
        $newTitle = $newTitle.Remove(0,1)
        $content = $content -replace $_, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
