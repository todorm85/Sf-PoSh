function sf-tests-startWebTestRunner {
    [SfProject]$p = sf-project-get
    if ($p) {
        $testRunnerPath = "C:\work\sitefinity-webtestrunner\Telerik.WebTestRunner.Client\bin\Release\app.publish"
        $testRunnerConfigPath = "$testRunnerPath\Telerik.WebTestRunner.Client.exe.Config"
        $allLines = Get-Content -Path $testRunnerConfigPath
        $newLines = $allLines | % {
            if ($_.Contains("TMITSKOV")) {
                return "<machine name=""TMITSKOV"" testingInstanceUrl=""$(sf-iis-site-getUrl)"" />"
            } else {
                return $_
            }
        } 

        Remove-Item -Path $testRunnerConfigPath -Force
        $newLines | Out-File -FilePath $testRunnerConfigPath -Append -Encoding utf8
    }

    & "$testRunnerPath\Telerik.WebTestRunner.Client.exe"
}

function sf-tests-runIntTests {
    param (
        $testsNames,
        $category
    )
    
    $system = sf-config-open -name "System"
    $ecommerce = $system | Select-Xml -XPath "//systemConfig/applicationModules/add[@name='Ecommerce']"
    $forums = $system | Select-Xml -XPath "//systemConfig/applicationModules/add[@name='Forums']"
    if (!$ecommerce -and !$forums) {
        sf-tests-prepareIntTests
    }

    $url = sf-iis-site-getUrl
    $testRunnerCmdPath = "C:\work\sitefinity-webtestrunner\Telerik.WebTestRunner.Cmd\bin\Release\Telerik.WebTestRunner.Cmd.exe"
    $command = "& '$testRunnerCmdPath' run /Url=""$url"" /RunName=""Test"""
    if ($testsNames) {
        $command += " /Tests=""$testsNames"""
    }

    if ($category) {
        $command += " /CategoriesFilter=""$category"""
    }

    Invoke-Expression -Command $command
}

function sf-tests-prepareIntTests {
    $p = sf-project-get

    $destinationDirectory = $p.webAppPath
    $configurationDirectory = "$destinationDirectory\App_Data\Sitefinity\Configuration"
    $sitefinityProductVersion = [version](Get-Item "$destinationDirectory\bin\Telerik.Sitefinity.dll" | Select-Object -ExpandProperty VersionInfo).ProductVersion
	$sitefinityMajorMinorVersion = [version]"$($sitefinityProductVersion.Major).$($sitefinityProductVersion.Minor)"
	
	if($sitefinityMajorMinorVersion -eq [version]"13.3")
	{		
		Write-Verbose "Turning Ecommerce module ON."
		#Enable Ecommerce in SystemConfig.config as it is currently disabled for new installations
		#and we want to keep the existing behaviour in order to keep runining the same test suites
		_updateSitefinityApplicationModule -moduleName "Ecommerce" -startupType OnApplicationStart -configurationDirectory $configurationDirectory
	}

	if($sitefinityMajorMinorVersion -ge [version]"14.1")
	{
		# WebForms deprecation - Forums module is disabled by default and PageTemplatesFrameworks is set to MvcOnly. We need the hybrid mode for tests validation
		Write-Verbose "Turning Forums module ON."
		_updateSitefinityApplicationModule -moduleName "Forums" -startupType OnApplicationStart -configurationDirectory $configurationDirectory
		Write-Verbose "Turning ResponsiveDesign module ON."
		_updateSitefinityApplicationModule -moduleName "ResponsiveDesign" -startupType OnApplicationStart -configurationDirectory $configurationDirectory
		Write-Verbose "Turning HybridAndMvc page templates framework ON."
		_updateSitefinityPageTemplatesFrameworks -framework HybridAndMvc -configurationDirectory $configurationDirectory
	}

    sf-iis-AppPool-Reset
    Start-Sleep -Seconds 1
    sf-app-ensureRunning
}

function sf-uitests-openSolution {
    [SfProject]$p = sf-project-get
    . "$($p.solutionPath)\Telerik.Sitefinity.MS.TestUI.sln"
}

function sf-uitests-setup {
    [SfProject]$p = sf-project-get
    if (!$p) {
        throw "no project"
    }

    _updateWebConfig
    _update_testCasesAppConfig
    _updateProjectData
    Write-Warning "Do not forget to select test settings file. TEST -> Test Settings -> UITestCasesLocal.testsettings"
}

function _updateSitefinityApplicationModule
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$moduleName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("OnApplicationStart", "OnFirstCall", "Manual", "Disabled")]
        [string]$startupType,

        [Parameter(Mandatory=$true)]
        [string]$configurationDirectory
    )

    $systemConfig = "$configurationDirectory\SystemConfig.config"

	$doc = New-Object System.Xml.XmlDocument
	if(!(Test-Path $systemConfig))
	{
		$doc.LoadXml("<?xml version=""1.0"" encoding=""utf-8""?><systemConfig xmlns:config=""urn:telerik:sitefinity:configuration"" xmlns:type=""urn:telerik:sitefinity:configuration:type""><applicationModules><add name=""$($moduleName)"" startupType=""$($startupType)""/></applicationModules></systemConfig>")
		$doc.Save($systemConfig);
	}
	else
    {
		$doc.Load($systemConfig)
		$systemConfigNode = $doc.SelectSingleNode("//systemConfig")
        $applicationModulesNode = $doc.SelectSingleNode("//systemConfig/applicationModules")
        if(-not $applicationModulesNode)
        {
		    $applicationModulesNode = $doc.CreateElement("applicationModules")
		    $systemConfigNode.AppendChild($applicationModulesNode)
        }

        $moduleNode = $doc.SelectSingleNode("//systemConfig/applicationModules/add[@name='$($moduleName)']")
        if(-not $moduleNode)
        {
		    $moduleNode = $doc.CreateElement("add")
		    $applicationModulesNode.AppendChild($moduleNode)
		    $moduleNode.SetAttribute("name", $moduleName)
        }

		$moduleNode.SetAttribute("startupType", $startupType)

		$doc.Save($systemConfig)
	}
}

function _updateSitefinityPageTemplatesFrameworks
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("All", "HybridAndMvc", "MvcOnly")]
        [string]$framework,

        [Parameter(Mandatory=$true)]
        [string]$configurationDirectory
    )

    $pagesConfig = "$configurationDirectory\PagesConfig.config"

	$doc = New-Object System.Xml.XmlDocument
	if(!(Test-Path $pagesConfig))
	{
		$doc.LoadXml("<?xml version=""1.0"" encoding=""utf-8""?><pagesConfig xmlns:config=""urn:telerik:sitefinity:configuration"" xmlns:type=""urn:telerik:sitefinity:configuration:type"" pageTemplatesFrameworks=""$($framework)""/>")
		$doc.Save($pagesConfig);
	}
	else
    {
		$doc.Load($pagesConfig)
		$pagesConfigNode = $doc.SelectSingleNode("//pagesConfig")
        $pagesConfigNode.SetAttribute("pageTemplatesFrameworks", $framework)

		$doc.Save($pagesConfig)
	}
}

function _updateProjectData {
    [SfProject]$p = sf-project-get
    $xmlPath = $p.solutionPath + "\Telerik.Sitefinity.MS.TestUI.TestCases\Data\ProjectData.xml"
    $projectPath = $p.solutionPath + "\Telerik.Sitefinity.MS.TestUI.TestCases"
    [XML]$xml = Get-Content $xmlPath
    $xml.projectData.projectPath = $projectPath
    _saveXml -xml $xml -path $xmlPath
}

function _update_testCasesAppConfig {
    [SfProject]$p = sf-project-get
    $appConfigPath = $p.solutionPath + "\Telerik.Sitefinity.MS.TestUI.TestCases\app.config"
    
    [XML]$appConfigContent = Get-Content $appConfigPath
    $defaultMachineConfig = $appConfigContent.SelectSingleNode("/configuration/machineSpecificConfigurations/machines/add[@name='default']");
    $url = sf-iis-site-getUrl
    $defaultMachineConfig.SetAttribute("baseUrl", $url) > $null

    $urlNodes = $defaultMachineConfig.SelectNodes("additionalUrls/add")
    $urlNodes | % {
        $_.value = $url
    }

    _saveXml -xml $appConfigContent -path $appConfigPath
}

function _updateWebConfig {
    [SfProject]$p = sf-project-get
    $webConfigPath = "$($p.webAppPath)\web.config"
    [XML]$webConfig = Get-Content $webConfigPath
    $appSettings = $webConfig.SelectSingleNode("/configuration/appSettings")
    $healthCheckNode = $appSettings.SelectSingleNode("add[@key='sf:HealthCheckApiEndpoint']")
    if (!$healthCheckNode) {
        $healthCheckNode = $webConfig.CreateElement("add")
        $healthCheckNode.SetAttribute("key", "sf:HealthCheckApiEndpoint")
        $healthCheckNode.SetAttribute("value", "restapi/health")
        $appSettings.AppendChild($healthCheckNode) > $null
        _saveXml -xml $webConfig -path $webConfigPath
    }
}

function _saveXml ($xml, $path) {
    attrib -r $path
    $xml.Save($path)
}