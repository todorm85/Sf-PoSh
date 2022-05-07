function sf-iris-configureStandalone {
    sf-config-update security {
        param($config)
        $config.securityConfig.SetAttribute("accessControlAllowOrigin", "*")
    }

    sf-config-update authentication {
        param($config)
        xml-getOrCreateElementPath -root $config.authenticationConfig -elementPath "oauthServer/authorizedClients/add[@clientId=sitefinity]/redirectUrls/add[@value=http://localhost:3000/auth/oauth/sign-in]"
    }

    sf-config-update -configName webServices {
        param($config)
        $configNamespace = "urn:telerik:sitefinity:configuration"
        $service = xml-getOrCreateElementPath -root $config."webServicesConfig" -elementPath "Routes/add[@name=Sitefinity]"
        $service.SetAttribute("flags", $configNamespace, "1")
        $cor = xml-getOrCreateElementPath -root $service -elementPath "services/add[@urlName=system]"
        $cor.SetAttribute("accessControlAllowOrigin", "*")
        $cor.SetAttribute("flags", $configNamespace, "1")
    }
}

function sf-iris-install {
    $p = sf-project-get
    RunInLocation -loc $p.webAppPath -script {
        Build\Iris\IrisInstall.ps1
    }
}