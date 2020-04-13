$Script:codeDeployment_ServicePath = "sf-dev\services"
$Script:codeDeployment_ResourcesPath = "$PSScriptRoot\resources"
$Script:codeDeployment_ServerCodePath = "App_Code\sf-dev\codeRunner"

$Global:SfEvents_OnAfterProjectSelected += { _sd-serverCode-deploy }

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

    sf-app-sendRequestAndEnsureInitialized > $null
    
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

function _sd-serverCode-deploy {
    [SfProject]$p = sf-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    $dest = "$($p.webAppPath)\$Script:codeDeployment_ServerCodePath"
    if (!(Test-Path $dest)) {
        New-Item -Path $dest -ItemType Directory > $null
    }

    Remove-Item "$dest\*" -Recurse -Force
    Copy-Item -Path "$($Script:codeDeployment_ResourcesPath)\*" -Destination $dest -Recurse -ErrorAction Ignore -Exclude "*.svc"

    $dest = "$($p.webAppPath)\$Script:codeDeployment_ServicePath"
    if (!(Test-Path $dest)) {
        New-Item -Path $dest -ItemType Directory > $null
    }

    Copy-Item -Path "$($Script:codeDeployment_ResourcesPath)\*" -Destination $dest -Recurse -ErrorAction Ignore -Filter "*.svc" -Force
}
