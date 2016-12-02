if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

function sf-copy-decModule {
    Param(
        [string]$decModuleDllsPath = "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector\bin\Debug",
        [string]$decIntegrationTestsDllsPath = "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug",
        [switch]$revert
        )

    $context = _sf-get-context
    $targetPath = "$($context.webAppPath)\bin"

    $decModuleDllsToCopy = @("Telerik.Sitefinity.DataIntelligenceConnector", "Telerik.DigitalExperienceCloud.Client" )
    $decIntegrationTestsDllsToCopy = @("Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests", "Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements", "Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities", "Telerik.WebTestRunner.Server", "Telerik.Sitefinity.TestArrangementService.Core", "WebDriver", "Gallio", "Gallio40", "MbUnit", "MbUnit40")

    ForEach ($dllName in $decModuleDllsToCopy) {
        Copy-Item "${decModuleDllsPath}\${dllName}.dll" "${targetPath}"
        Copy-Item "${decModuleDllsPath}\${dllName}.pdb" "${targetPath}"
    }

    ForEach ($dllName in $decIntegrationTestsDllsToCopy) {
        Copy-Item "${decIntegrationTestsDllsPath}\${dllName}.dll" "${targetPath}"
        Copy-Item "${decIntegrationTestsDllsPath}\${dllName}.pdb" "${targetPath}"
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

function sf-open-dec {

    & "D:\DEC-Connector\data-intell-sitefinity-connector\DataIntellConnector.sln"
}