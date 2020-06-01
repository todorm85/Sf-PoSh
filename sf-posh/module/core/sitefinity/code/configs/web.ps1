function sf-configWeb-setMachineKey {
    Param(
        $decryption = "AES",
        $decryptionKey = "53847BC18AFFC19E5C1AC792A4733216DAEB54215529A854",
        $validationKey = "DC38A2532B063784F23AEDBE821F733625AD1C05D4718D2E0D55D842DAC207FB8492043E2EE5861BB3C4B0C4742CF73BDA586A70BDDC4FD50209B465A6DBBB3D"
    )

    [XML]$xmlDoc = sf-config-open "web"
    $machineKey = sf-config-getOrCreateElementPath -parent $xmlDoc.configuration -elementPath "system.web,machineKey"
    $machineKey.SetAttribute("decryption", $decryption)
    $machineKey.SetAttribute("decryptionKey", $decryptionKey)
    $machineKey.SetAttribute("validationKey", $validationKey)
    sf-config-save $xmlDoc
}

function sf-configWeb-removeMachineKey {
    [XML]$xmlDoc = sf-config-open "web"
    $systemWeb = $xmlDoc.Configuration["system.web"]
    $machineKey = $systemWeb.machineKey
    if ($machineKey) {
        $systemWeb.RemoveChild($machineKey) > $null
    }

    sf-config-save -config $xmlDoc
}