<#
.EXAMPLE
$path = "tf.exe"
execute-native "& `"$path`" workspaces `"C:\dummySubApp`""
#>
function execute-native ($command) {
    $output = Invoke-Expression $command
    
    if ($LastExitCode -ne 0) {
        throw $output
    }
    else {
        $output
    }
}
