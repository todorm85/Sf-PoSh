# to use in PS5 type "Install-Module ImportExcel" GitHub: dfinke/ImportExcel

function convertAll-xml2xls {
    Param([string]$dirPath)
    
    $filesAndDirs = get-childitem $dirPath
    $txtFilePaths = $filesAndDirs | where {$_.extension -eq ".xml"}
    foreach($path in $txtFilePaths) {
        convert-xml2xls $path
    }
}

function convert-xml2xls {
    Param($path)

    $data = New-Object XML
    $data.Load($path.FullName)
    $testResults = $data.TestResults.testRun.RunnerTestResult
    
    $testResultsFiltered = $testResults | Select-Object -Property FixtureName, TestMethodName, AuthorName, Result, StartTime, EndTime, TestDuration, IdentificationKey, Message

    # $testResultsFiltered
    $testResultsFiltered | Export-Excel "$($path.Directory.FullName)\$($path.BaseName).xlsx"
}


