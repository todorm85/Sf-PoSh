$handleLink = "https://download.sysinternals.com/files/Handle.zip"
$handleExternalToolsDir = "$PSScriptRoot\external-tools\handle"
if (!(Test-Path $handleExternalToolsDir)) {
    New-Item -Path $handleExternalToolsDir -ItemType Directory
}

$handleToolPath = "$handleExternalToolsDir\handle.exe"
if (!(Test-Path $handleToolPath)) {
    $archive = "$handleExternalToolsDir\Handle.zip"
    try {
        Invoke-WebRequest -Uri $handleLink -OutFile $archive
        expand-archive -path $archive -destinationpath $handleExternalToolsDir
        . "$handleExternalToolsDir\Eula.txt"
        Remove-Item -Path $archive -Force
    }
    catch {
        Write-Error "Error fetching the handle tool from $handleLink auto unlocking files will not work."        
    }
}