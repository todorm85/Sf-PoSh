function sd-nginx-reset {
    # Get-Process -Name "nginx" -ErrorAction "SilentlyContinue" | Stop-Process -Force
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

    _nginx-initializeConfig

    $nlbTag = _nlbTags-create
    
    os-hosts-add -hostname (_nlbTags-getDomain $nlbTag)

    _nginx-createNlbClusterConfig $nlbTag $firstNode $secondNode
    
    # update project tags
    $firstNode.tags.Add($nlbTag)
    sd-project-save $firstNode
    $secondNode.tags.Add($nlbTag)
    sd-project-save $secondNode

    sd-nginx-reset
}

function _s-nginx-removeCluster {
    param (
        $nlbTag
    )
    
    $clusterId = _nlbTags-getClusterIdFromTag $nlbTag
    $nlbPairConfigPath = "$(_get-toolsConfigDirPath)\$($clusterId).config"
    Remove-Item -Path $nlbPairConfigPath -Force

    $nlbDomain = _nlbTags-getDomain -tag $nlbTag
    os-hosts-remove -hostname $nlbDomain
}

function _nginx-createNlbClusterConfig {
    param (
        [string]$nlbTag,
        [SfProject]$firstNode,
        [SfProject]$secondNode
    )

    $nlbClusterId = _nlbTags-getClusterIdFromTag -tag $nlbTag
    if (!$nlbClusterId) {
        throw "Invalid cluster id."
    }

    $nlbDomain = _nlbTags-getDomain -tag $nlbTag

    [SiteBinding]$firstNodeBinding = sd-bindings-getOrCreateLocalhostBinding -project $firstNode
    [SiteBinding]$secondNodeBinding = sd-bindings-getOrCreateLocalhostBinding -project $secondNode

    $nlbPairConfig = "upstream $nlbClusterId {
    server localhost:$($firstNodeBinding.port);
    server localhost:$($secondNodeBinding.port);
}

server {
    listen 443 ssl;
    server_name $nlbDomain;
    proxy_set_header Host `$host;
    include sf-dev/common.conf;
    location / {
        proxy_pass http://$nlbClusterId;
    }
}

server {
    listen 80;
    server_name $nlbDomain;
    proxy_set_header Host `$host;
    include sf-dev/common.conf;
    location / {
        proxy_pass http://$nlbClusterId;
    }
}"

    $nlbPairConfigPath = "$(_get-toolsConfigDirPath)\$($nlbClusterId).config"
    $nlbPairConfig | _nginx-writeConfig -path $nlbPairConfigPath
}

function _nginx-escapePathForConfig {
    param (
        [string]$value
    )
    
    $value.Replace("\", "\\")
}

function _nginx-initializeConfig {
    $toolConfDirPath = _get-toolsConfigDirPath
    if (!(Test-Path $toolConfDirPath)) {
        Copy-Item "$PSScriptRoot\resources\nginx\*" (_getNginxConfigDirPath) -Recurse -Force
        Import-Certificate -FilePath "$PSScriptRoot\resources\nginx\sf-dev\sfdev.crt" -CertStoreLocation "Cert:\LocalMachine\Root" > $null
    }
}

function _nginx-writeConfig {
    [CmdletBinding()]
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