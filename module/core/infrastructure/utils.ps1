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
