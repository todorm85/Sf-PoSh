function sf-prepareEmptyProjects {
    if (-not (Test-Path '\\progress.com\corp\sofia')) {
        throw "You must have VPN in order to build projects!"
    }

    sf-project-get -all | ? displayName -eq '' | Run-InProjectScope -script {
        if (sf-source-hasSourceControl) {
            sf-paths-goto -root
            git restore *
            git clean -fd
            git pull
        }

        sf-sol-clean;
        sf-sol-build;
        sf-app-reinitialize;
        sf-states-save init;
        Start-Sleep -Seconds 10;
        iisreset.exe
    }
}