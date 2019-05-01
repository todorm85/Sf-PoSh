$source = "$PSScriptRoot\..\sf-dev\sf-dev.psd1"
$target = "$PSScriptRoot\..\sf-dev\sf-dev.dev.psd1"
$sourceLines = Get-Content $source
$targetLines = $sourceLines | % {
    if ($_.Contains('FunctionsToExport')) {
        "FunctionsToExport = '*'"
    } else {
        $_
    }
}

$targetLines | Out-File -FilePath $target -Encoding utf8