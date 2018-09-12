function prompt-containerSelect {
    $allContainers = @(_sfData-get-allContainers)
    [System.Collections.ArrayList]$output = @()
    if ($null -ne $allContainers[0]) {
        foreach ($container in $allContainers) {
            $index = [array]::IndexOf($allContainers, $container)
            $output.add([pscustomobject]@{order = $index; Title = "$index : $($container.name)"; }) > $null
        }
    }

    $output.add([pscustomobject]@{order = ++$index; Title = "$index : none"; }) > $null
    $output | Sort-Object -Property order | Format-Table -AutoSize -Property Title | Out-String | ForEach-Object { Write-Host $_ }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose container'
        if ($choice -eq $index) {
            return [pscustomobject]@{ name = "" }
        }

        $selected = $allContainers[$choice]
        if ($null -ne $selected) {
            return [pscustomobject]@{ name = "$($selected.name)" }
        }
    }
}
