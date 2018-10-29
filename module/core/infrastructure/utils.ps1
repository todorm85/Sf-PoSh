<#
.EXAMPLE
$path = "tf.exe"
execute-native "& `"$path`" workspaces `"C:\dummySubApp`""
#>
function execute-native ($command) {
    $output = Invoke-Expression $command
    
    if ($Global:LASTEXITCODE) {
        throw "Error: $output"
    }
    else {
        $output
    }
}

function unlock-allFiles ($path) {
    $handlesList = execute-native "& `"$Script:externalTools\handle.exe`" $path"
    $pids = New-Object -TypeName System.Collections.ArrayList
    $handlesList | ForEach-Object { 
        $isFound = $_ -match "^.*pid: (?<pid>.*?) .*$"
        if ($isFound) {
            $id = $Matches.pid
            if (-not $pids.Contains($id)) {
                $pids.Add($id)
            }
        }
    }

    $pids | ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
}