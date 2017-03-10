if ($false) {
    . .\..\sf-all-dependencies.ps1 # needed for intellisense
}

$DecSolutionPath = "D:\DEC-Connector\data-intell-sitefinity-connector"

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sfDec-copy-decModule {
    [CmdletBinding()]
    Param(
        [string]$decModuleDllsPath = "${DecSolutionPath}\Telerik.Sitefinity.DataIntelligenceConnector\bin\Debug",
        [string]$decIntegrationTestsDllsPath = "${DecSolutionPath}\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug",
        [switch]$revert,
        [switch]$copyTestDlls
        )

    $context = _sf-get-context
    $targetPath = "$($context.webAppPath)\bin"

    $decModuleDllsToCopy = @(
        "Telerik.Sitefinity.DataIntelligenceConnector",
        "Telerik.DigitalExperienceCloud.Client"
      )
    $decIntegrationTestsDllsToCopy = @(
        "Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests", 
        "Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements", 
        "Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities", 
        "Telerik.WebTestRunner.Server", 
        "Telerik.Sitefinity.TestArrangementService.Core", 
        "WebDriver",
        "Gallio", 
        "Gallio40", 
        "MbUnit", 
        "MbUnit40"
     )

    ForEach ($dllName in $decModuleDllsToCopy) {
        Copy-Item "${decModuleDllsPath}\${dllName}.dll" "${targetPath}"
        Copy-Item "${decModuleDllsPath}\${dllName}.pdb" "${targetPath}"
    }

    if ($copyTestDlls) {
        ForEach ($dllName in $decIntegrationTestsDllsToCopy) {
            Copy-Item "${decIntegrationTestsDllsPath}\${dllName}.dll" "${targetPath}"
            Copy-Item "${decIntegrationTestsDllsPath}\${dllName}.pdb" "${targetPath}"
        }
    }

    if ($revert) {
        
        ForEach ($dllName in $decModuleDllsToCopy) {
            Remove-Item "${targetPath}\${dllName}.dll"
            Remove-Item "${targetPath}\${dllName}.pdb"
        }

        ForEach ($dllName in $decIntegrationTestsDllsToCopy) {
            Remove-Item "${targetPath}\${dllName}.dll"
            Remove-Item "${targetPath}\${dllName}.pdb"
        }
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sfDec-open-dec {
    [CmdletBinding()]
    Param()
    
    & "${DecSolutionPath}\DataIntellConnector.sln"
}

Export-ModuleMember -Function '*'