$Script:codeDeployment_ServicePath = "sf-posh\services"
$Script:codeDeployment_ResourcesPath = "$PSScriptRoot\resources"
$Script:codeDeployment_ServerCodePath = "App_Code\sf-posh\codeRunner"

$Global:SfEvents_OnAfterProjectInitialized += { _sf-serverCode-deployHandler }

function sf-serverCode-run {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$typeName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$methodName,

        [string[]]$parameters
    )
    
    $parametersString = ""
    $parameters | % { $parametersString += ";$_" }
    $parametersString = $parametersString.TrimStart(';')

    $encodedType = [System.Web.HttpUtility]::UrlEncode($typeName)
    $encodedParams = [System.Web.HttpUtility]::UrlEncode($parametersString)
    $encodedMethod = [System.Web.HttpUtility]::UrlEncode($methodName)
    $serviceRequestPath = "CodeRunner.svc/CallMethod?methodName=$encodedMethod&typeName=$encodedType&params=$encodedParams"

    sf-app-ensureRunning -InformationAction:SilentlyContinue > $null
    
    $baseUrl = sf-iisSite-getUrl
    $response = Invoke-WebRequest -Uri "$baseUrl/$($Script:codeDeployment_ServicePath.Replace('\', '/'))/$serviceRequestPath"
    if ($response.StatusCode -ne 200) {
        Write-Error "Response status code for call $serviceRequestPath was not 200 OK."
    }
    else {
        Write-Information "Call to $serviceRequestPath complete!"
    }

    if ($response.Content) {
        return $response.Content | ConvertFrom-Json
    }
    else {
        return $response
    }
}

function _sf-serverCode-deployHandler {
    [SfProject]$p = sf-project-get
    if (!$p) {
        throw "No project selected."
    }

    sf-serverCode-deployDirectory "$($Script:codeDeployment_ResourcesPath)\code" $Script:codeDeployment_ServerCodePath

    sf-serverCode-deployDirectory "$($Script:codeDeployment_ResourcesPath)\services" $Script:codeDeployment_ServicePath
}

function _sf-serverCode-areSourceAndTargetSfDevVersionsEqual {
    param (
        [Parameter(Mandatory=$true)]$src,
        [Parameter(Mandatory=$true)]$trg
    )
    
    if (!(Test-Path $trg)) {
        return $false
    }

    $trgSign = Get-ChildItem $trg -Filter "*.sfdevversion"
    $srcSign = Get-ChildItem $src -Filter "*.sfdevversion"
    if ($trgSign -and $srcSign -and $trgSign.BaseName -eq $srcSign.BaseName) {
        return $true
    }

    return $false
}

function sf-serverCode-deployDirectory {
    param (
        [Parameter(Mandatory=$true)]$sourcePath,
        [Parameter(Mandatory=$true)]$appRelativeTargetPath
    )

    $p = sf-project-get
    $trg = "$($p.webAppPath)\$appRelativeTargetPath"
    if (!(Test-Path $trg)) {
        New-Item -Path $trg -ItemType Directory > $null
    }
    
    if ((_sf-serverCode-areSourceAndTargetSfDevVersionsEqual $sourcePath $trg)) {
        return
    }    

    Remove-Item "$trg\*" -Recurse -Force
    Copy-Item -Path "$sourcePath\*" -Destination $trg -Recurse
}