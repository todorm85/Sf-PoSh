function stop-allMsbuild {
    try {
        Get-Process msbuild -ErrorAction Stop | Stop-Process -ErrorAction Stop
    }
    catch {
        Write-Warning "MSBUILD stop: $_"
    }
}
