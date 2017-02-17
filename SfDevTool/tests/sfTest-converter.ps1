# to use in PS5 type "Install-Module ImportExcel" GitHub: dfinke/ImportExcel

function sfTest-convert-xml2xls {
    Param([string]$path)
    
    [System.Collections.ArrayList]$testsToExport = @()

    $pathInfo = get-childitem $path
    $xmlPathInfos = $pathInfo | where {$_.extension -eq ".xml"}
    foreach($xmlPathInfo in $xmlPathInfos) {
        $testsMessages = [System.Collections.ArrayList]@()
        $tests = _load-testsFromXml $xmlPathInfo.FullName

        foreach($test in $tests) {
            if ($test.Result -ne "Failed") {
                continue
            }

            $test.Message -match "^(?<msgLoc>(.|\n)*?)\n   at " > $Null
            $testMessage = $matches["msgLoc"]

            $errorGroupId = _set-errorGroupId $testsMessages $testMessage
            $test | Add-Member ErrorGruop $errorGroupId
            $testsToExport.Add($test) > $Null
        }

        $testsToExport | Export-Excel "$($xmlPathInfo.Directory.FullName)\$($xmlPathInfo.BaseName).xlsx"
    }
}
