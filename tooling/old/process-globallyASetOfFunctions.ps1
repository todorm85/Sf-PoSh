# $path = "$PSScriptRoot\..\dev\core"
$path = "$PSScriptRoot\..\"

# $oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames = @('sf-project-getAll')

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
        [string]$oldName = [string]$_
        $newTitle = "" + $oldName
        $content = $content -replace $oldName, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
