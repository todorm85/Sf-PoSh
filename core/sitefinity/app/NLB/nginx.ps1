$global:nlbClusterConfigExtension = "config"
function sf-nginx-reset {
    $nginxDirPath = (Get-Item $Global:sf.config.pathToNginxConfig).Directory.Parent.FullName
    $nginxJob = Start-Job -ScriptBlock {
        param($nginxDirPath)
        Get-Process nginx | Stop-Process -Force -ErrorAction SilentlyContinue
        
        Set-Location $nginxDirPath
        ./nginx.exe
    } -ArgumentList $nginxDirPath

    Start-Sleep 1
    $nginxJob | Receive-Job
}

function _nginx-createNewCluster {
    param (
        [SfProject]$firstNode,
        [SfProject]$secondNode
    )

    _nginx-initializeConfig > $null
    $nlbId = [Guid]::NewGuid().ToString().Split('-')[0]
    
    os-hosts-add -hostname (_nlb-generateDomain $nlbId) > $null
    _nginx-createNlbClusterConfig -nlbClusterId $nlbId -firstNode $firstNode -secondNode $secondNode > $null
    sf-nginx-reset > $null
    
    $nlbId
}

function _s-nginx-removeCluster {
    param (
        $nlbTag
    )
    
    $clusterId = $nlbTag
    $nlbDomain = _nginx-getNlbClusterDomain $clusterId
    $nlbPairConfigPath = _nginx-getClusterConfigPath $clusterId
    Remove-Item -Path $nlbPairConfigPath -Force
    os-hosts-remove -hostname $nlbDomain
}

function _nginx-getNlbClusterDomain {
    param (
        [string]$nlbClusterId
    )
    
    $nlbPairConfigPath = _nginx-getClusterConfigPath $nlbClusterId
    Get-Content -Path $nlbPairConfigPath | % {
        if ($_ -Match " *?server_name (?<host>.*).*;") {
            $Matches.host
        }
    } | Select-Object -First 1
}

function _nginx-renameNlbClusterDomain {
    param (
        [string]$nlbClusterId,
        [string]$newHostName
    )
    
    $nlbPairConfigPath = _nginx-getClusterConfigPath $nlbClusterId
    $nlbPairConfig = ""
    Get-Content -Path $nlbPairConfigPath | % {
        $line = $_
        if ($_ -Match " *?server_name (?<host>.*);") {
            $line = $_.Replace($Matches.host, $newHostName)
        }

        $nlbPairConfig += $line
        $nlbPairConfig += [System.Environment]::NewLine
    }

    $nlbPairConfig | _nginx-writeConfig -path $nlbPairConfigPath
}

function _nginx-createNlbClusterConfig {
    param (
        [string]$nlbClusterId,
        [SfProject]$firstNode,
        [SfProject]$secondNode
    )

    if (!$nlbClusterId) {
        throw "Invalid cluster id."
    }

    $nlbDomain = _nlb-generateDomain $nlbClusterId

    [SiteBinding]$firstNodeBinding = sf-bindings-getOrCreateLocalhostBinding -project $firstNode
    [SiteBinding]$secondNodeBinding = sf-bindings-getOrCreateLocalhostBinding -project $secondNode

    $nlbPairConfig = "upstream $nlbClusterId {
    server localhost:$($firstNodeBinding.port);
    server localhost:$($secondNodeBinding.port);
}

server {
    listen 443 ssl;
    server_name $nlbDomain;
    proxy_set_header Host `$host;
    include sf-posh/common.conf;
    location / {
        proxy_read_timeout 180s;
        proxy_pass http://$nlbClusterId;
    }
}

server {
    listen 80;
    server_name $nlbDomain;
    proxy_set_header Host `$host;
    include sf-posh/common.conf;
    location / {
        proxy_read_timeout 180s;
        proxy_pass http://$nlbClusterId;
    }
}"

    $nlbPairConfigPath = _nginx-getClusterConfigPath $nlbClusterId
    $nlbPairConfig | _nginx-writeConfig -path $nlbPairConfigPath
}

function _nginx-escapePathForConfig {
    param (
        [string]$value
    )
    
    $value.Replace("\", "\\")
}

function _nginx-initializeConfig {
    $src = "$PSScriptRoot\resources\nginx"
    $trg = _nginx-getConfigDirPath
    if (!(_sf-serverCode-areSourceAndTargetSfDevVersionsEqual $src $trg)) {
        Copy-Item "$src\*" $trg -Recurse -Force
        $certificate = get-item "Cert:\LocalMachine\Root\c993ecf08a781102da4936160849281d3d8e78ec" -ErrorAction:SilentlyContinue
        if (!$certificate) {
            Import-Certificate -FilePath "$src\sf-posh\sfdev.crt" -CertStoreLocation "Cert:\LocalMachine\Root" > $null
        }
    }

}

function _nginx-writeConfig {
    param (
        [Parameter(ValueFromPipeline)]
        $content,
        $path
    )

    process {
        if (!(Test-Path $path)) {
            New-Item $path -ItemType File > $null
        }

        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($path, $content, $Utf8NoBomEncoding) > $null
    }
}