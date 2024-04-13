function asp-cleanTemp {
    $codeGenDir = [System.Web.HttpRuntime]::CodegenDir
    Remove-Item -Path $codeGenDir -Recurse -Force
}