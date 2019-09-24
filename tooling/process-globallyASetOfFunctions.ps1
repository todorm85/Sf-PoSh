$oldNames = & "$PSScriptRoot/get-publicFunctions.ps1" -path "C:\Users\User\Desktop\sf-dev\tests"

function Convert-ToPascalCase {
    param (
        [string]$text
    )
    
    $text = $text.Replace("sf-", "");
    $result = "";
    $setCapital = $true;
    for ($i = 0; $i -lt $text.Length; $i++) {
        $letter = $text[$i]
        if ($setCapital) {
            $newResult = $letter.ToString().ToUpperInvariant();
        } else {
            $newResult = $letter
        }
        
        $result = "$result$newResult"

        if ($letter -eq '-') {
            $setCapital = $true;
        } else {
            $setCapital = $false;
        }
    }

    $result
}

$scripts = Get-ChildItem "$PSScriptRoot\..\sf-dev\core" -Recurse | Where-Object { $_.Extension -eq '.ps1'}

$scripts | % { 
    $content = Get-Content $_.FullName
    $oldNames | % {
        $newTitle = Convert-ToPascalCase($_)
        # $newTitle = "_$_"
        $content = $content -replace $_, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
