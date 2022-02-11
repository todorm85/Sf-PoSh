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