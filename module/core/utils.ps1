<#
.EXAMPLE
$path = "tf.exe"
execute-native "& `"$path`" workspaces `"C:\dummySubApp`""
#>
function execute-native ($command) {
    $output = Invoke-Expression $command
    
    if ($LastExitCode) {
        throw "Error: $output"
    }
    else {
        $output
    }
}
