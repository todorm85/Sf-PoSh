$type = Get-Content "$PSScriptRoot\NlbEntity.cs" -Raw | Out-String
Add-Type -TypeDefinition $type

function _nlbData-getPath {
    $dataPath = "$((get-item $sf.config.dataPath).Directory.FullName)\nlb.json"
    if (!(Test-Path $dataPath)) {
        @() | ConvertTo-Json | Out-File $dataPath
    }

    $dataPath
}

function sf-nlbData-get {
    [OutputType([NlbEntity[]])]
    param()
    $dataFile = _nlbData-getPath
    [NlbEntity[]](Get-Content $dataFile -Raw | ConvertFrom-Json)
}

function _nlbData-set {
    param (
        [NlbEntity[]]
        $data
    )
    
    if (!$data) {
        $data = @()
    }
    
    $dataFile = _nlbData-getPath
    $data | ConvertTo-Json | Out-File $dataFile
}

function sf-nlbData-add {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [NlbEntity]$entry
    )
    
    $entries = @(sf-nlbData-get)
    if ($entries -contains $entry) {
        Write-Information "Entry already exists"
        return
    }

    $entries += $entry
    _nlbData-set $entries
}

function sf-nlbData-remove {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [NlbEntity]$entry
    )
    
    $entries = sf-nlbData-get
    $res = $entries | ? { $_ -ne $entry }
    _nlbData-set $res
}

function sf-nlbData-getProjectIds {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $nlbId
    )
    
    sf-nlbData-get | ? { $_.NlbId -eq $nlbId } | select -ExpandProperty ProjectId
}

function sf-nlbData-getNlbIds {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $projectId
    )

    sf-nlbData-get | ? { $_.ProjectId -eq $projectId } | select -ExpandProperty NlbId
}