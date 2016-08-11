$_featherRootPath = $False

function feather {
    #region Params

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [ValidateSet('build', 'update', 'copy', 'magic', 'setup')]
        [System.String]$Command,

        [Parameter(Mandatory=$False, Position = 1)]
        [ValidateSet('all', 'feather', 'widgets', 'packages', 'mvc')]
        [System.String]$ProjectsOption,

        [Parameter(Mandatory=$False, Position = 2)]
        [ValidateSet('rebuild', 'normal')]
        [System.String]$BuildOption,

        [Parameter(Mandatory=$False, Position = 3)]
        [ValidateSet('stash', 'force', 'normal')]
        [System.String]$GitOption,

        [Parameter(Mandatory=$False, Position = 4)]
        [System.String]$GitBranch
    )
    
    $_featherSettings = @{};

    #endregion

    #region Helpers

    function CreateNewFile {
        param(
            [Parameter(Mandatory=$True, Position = 0)]
            [System.String]$FileLocation,

            [Parameter(Mandatory=$True, Position = 1)]
            [System.String]$FileContent
        )

        New-Item $FileLocation -type file -force -value $FileContent | Out-Null
    }

    function Log {
        param(
            [Parameter(Mandatory=$False, Position = 0)]
            [System.String[]]$Message,

            [Parameter(Mandatory=$False, Position = 1)]
            [ConsoleColor[]]$Color,
            
            [Parameter(Mandatory=$False, Position = 2)]
            [System.Boolean]$NoNewLine
        )

        for ($i = 0; $i -lt $Message.Length; $i++) {
            Write-Host $Message[$i] -Foreground $Color[$i] -NoNewLine
        }

        IF(!$NoNewLine) {
            Write-Host
        }
    }

    function Prompt {
        param(
            [Parameter(Mandatory=$False, Position = 0)]
            [System.String]$Message
        )

        $input = Read-Host $Message           

        while($input -notin 'y', 'n', 'Y', 'N') {
            $input = Read-Host $Message
        }
            
        $input = $input.ToLower()
        IF ($input -eq 'y') {
            return $True
        }
        ELSE {
            return $False
        }
    }

    function PromptProjectsOption {
        param(
            [Parameter(Mandatory=$False, Position = 0)]
            [System.String]$Message
        )

        $input = Read-Host $Message           

        while($input -notin 'all', 'feather', 'widgets', 'packages', 'mvc') {
            $input = Read-Host 'Invalid option'
        }

        return $input
    }

    #endregion

    #region Setup

    $_settingsFileLocation = Join-Path $_featherRootPath 'feather-settings.json'
    
    function Initial-Settings {
        return @{
            basic = @{
	            Feather_Project_Path = "";
	            Feather_Widgets_Project_Path = "";
	            Feather_Packages_Project_Path = "";
                Sitefinity_Mvc_Project_Path = "";
	            Sitefinity_Web_App_Path = "";
            };
            advanced = @{
	            featherSolutionPath = "";
	            featherDlls = "", "";
	
	            featherWidgetsSolutionPath = "";
                featherWidgetsDlls = "","";
                
                sfMvcSolutionPath = "";
                sfMvcDlls = "","";

                sfWebAppBinPath = "";
                sfWebAppResourcePackagesPath = "";

                buildLogFileLocation = "";
            };
            constants = @{
                featherSolutionName = "Feather.sln";
                featherBinFolderName= "Telerik.Sitefinity.Frontend\bin\Debug";
                featherDllPath = "Telerik.Sitefinity.Frontend\bin\Debug\Telerik.Sitefinity.Frontend.dll";
                featherNinjectDllPath = "Telerik.Sitefinity.Frontend\bin\Debug\Ninject.dll";
                featherNinjectWebCommonDllPath = "Telerik.Sitefinity.Frontend\bin\Debug\Ninject.Web.Common.dll";
                featherRazorGeneratorMvcDllPath = "Telerik.Sitefinity.Frontend\bin\Debug\RazorGenerator.Mvc.dll";
                featherFrontendDataDllPath = "Telerik.Sitefinity.Frontend\bin\Debug\Telerik.Sitefinity.Frontend.Data.dll";
                featherTestUtilitiesDllPath = "Tests\Telerik.Sitefinity.Frontend.TestUtilities\bin\Debug\Telerik.Sitefinity.Frontend.TestUtilities.dll";
                featherIntegrationTestsDllPath = "Tests\Telerik.Sitefinity.Frontend.TestIntegration\bin\Debug\Telerik.Sitefinity.Frontend.TestIntegration.dll";
                
	            featherWidgetsSolutionName = "FeatherWidgets.sln";
                featherWidgetsFoldersPrefix = "Telerik.Sitefinity.Frontend.";
                featherWidgetsBinFolderName = "bin\Debug";
                featherWidgetsTestUtilitiesDllPath = "Tests\FeatherWidgets.TestUtilities\bin\Debug\FeatherWidgets.TestUtilities.dll";
                featherWidgetsIntegrationTestsDllPath = "Tests\FeatherWidgets.TestIntegration\bin\Debug\FeatherWidgets.TestIntegration.dll";

                featherPackagesFolderNames = "Bootstrap","Foundation","SemanticUI";
                
                sfMvcSolutionName = "Telerik.Sitefinity.Mvc.sln";
                sfMvcDllPath = "Telerik.Sitefinity.Mvc\bin\Debug\Telerik.Sitefinity.Mvc.dll";
                sfMvcTestUtilitiesDllPath = "Tests\Telerik.Sitefinity.Mvc.TestUtilities\bin\Debug\Telerik.Sitefinity.Mvc.TestUtilities.dll";
                sfMvcTestIntegrationDllPath = "Tests\Telerik.Sitefinity.Mvc.TestIntegration\bin\Debug\Telerik.Sitefinity.Mvc.TestIntegration.dll";

                sfWebAppBinFolderName = "bin";
                sfWebAppResourcePackagesFolderName = "ResourcePackages";
                
	            buildLogFile = "build-log.txt";

                sfMvcPackageName = 'Telerik.Sitefinity.Mvc';
                sfMvcTestUtilitiesPackageName = 'Telerik.Sitefinity.Mvc.TestUtilities';

                featherPackageName = 'Telerik.Sitefinity.Frontend';
                featherTestUtilitiesPackageName = 'Telerik.Sitefinity.Frontend.TestUtilities';
            };
            system = @{
	            GIT_EXE = "C:\Program Files (x86)\Git\bin\git.exe";
	            GIT_EXE_BACKUP = "C:\Program Files\Git\bin\git.exe";
	            MS_BUILD_EXE = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\msbuild.exe";
	            MS_BUILD_EXE_BACKUP = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe";
            };
        }
    }
    
    function Load-Settings {
        $localSettings = @{}
        $initialSettings = Initial-Settings

        IF (Test-Path $_settingsFileLocation) {
            #Settings file exists - load it
            $settingsObject = (Get-Content $_settingsFileLocation -Raw) | ConvertFrom-Json
            
            $localSettings.Add('basic', @{
                Feather_Project_Path = $settingsObject.basic.Feather_Project_Path;
                Feather_Widgets_Project_Path = $settingsObject.basic.Feather_Widgets_Project_Path;
                Feather_Packages_Project_Path = $settingsObject.basic.Feather_Packages_Project_Path;
                Sitefinity_Mvc_Project_Path = $settingsObject.basic.Sitefinity_Mvc_Project_Path;
                Sitefinity_Web_App_Path = $settingsObject.basic.Sitefinity_Web_App_Path;
            });

            $localSettings.Add('advanced', $settingsObject.advanced);
            $localSettings.Add('constants', $settingsObject.constants);
            $localSettings.Add('system', $settingsObject.system);
        }
        ELSE {
            #No settings file - load the default ones
            $localSettings = $initialSettings
        }

        Set-Variable -Scope 1 -Name "_featherSettings" -Value $localSettings
    }

    function Read-PathValue {
        $changedValue = Read-Host "New Path "

        While([System.String]::IsNullOrEmpty($changedValue) -or (-not (Test-Path $changedValue))) {
            Log 'Invalid path - try again' Red
            $changedValue = Read-Host "New Value "
        }

        return $changedValue.ToString()
    }

    function Read-Settings {
        foreach ($kv in $_featherSettings.basic.Clone().GetEnumerator()) {
            $projectName = $kv.Key.ToString().Substring(0, ($kv.Key.ToString().Length - 5))
            IF($kv.Value) {
                Log 'Project ',$projectName,' has path -> ',$kv.Value White,Green,White,Green

                $doChange = Prompt "Change Y/N ? "
                IF ($doChange) {
                    $_featherSettings.basic.Set_Item($kv.Key, (Read-PathValue))
                }
            }
            ELSE {
                Log 'Project ',$projectName,' has no path' White,Green,Red
                $_featherSettings.basic.Set_Item($kv.Key, (Read-PathValue))
            }
        }
    }
        
    function Update-Settings {
        Log 'Updating settings...' White

        #Feather
            #Solution
        $_featherSettings.advanced.featherSolutionPath = Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherSolutionName
            #Dlls
        $_featherSettings.advanced.featherDlls = @()
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherDllPath)
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherNinjectDllPath)
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherNinjectWebCommonDllPath)
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherRazorGeneratorMvcDllPath)
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherFrontendDataDllPath)
            #Tests
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherIntegrationTestsDllPath)
        $_featherSettings.advanced.featherDlls += ,(Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherTestUtilitiesDllPath)
		


        #FeatherWidgets
            #Solution
        $_featherSettings.advanced.featherWidgetsSolutionPath = Join-Path $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.featherWidgetsSolutionName
            #Dlls
        $_featherSettings.advanced.featherWidgetsDlls = @()
        $allWidgetFolders = Get-ChildItem ($_featherSettings.basic.Feather_Widgets_Project_Path + '\' + $_featherSettings.constants.featherWidgetsFoldersPrefix + '*')
        Foreach($widgetFolder in $allWidgetFolders) {
            $widgetDll = Join-Path (Join-Path $widgetFolder $_featherSettings.constants.featherWidgetsBinFolderName) $widgetFolder.ToString().Substring($widgetFolder.ToString().LastIndexOf('\'))
            $_featherSettings.advanced.featherWidgetsDlls += ,($widgetDll + '.dll')
        }
            #Tests
        $_featherSettings.advanced.featherWidgetsDlls += ,(Join-Path $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.featherWidgetsIntegrationTestsDllPath)
        $_featherSettings.advanced.featherWidgetsDlls += ,(Join-Path $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.featherWidgetsTestUtilitiesDllPath)



        #Sitefinity MVC
            #Solution
        $_featherSettings.advanced.sfMvcSolutionPath = Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcSolutionName
            #Dlls
        $_featherSettings.advanced.sfMvcDlls = @()
        $_featherSettings.advanced.sfMvcDlls += ,(Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcDllPath)
            #Tests
        $_featherSettings.advanced.sfMvcDlls += ,(Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcTestUtilitiesDllPath)
        $_featherSettings.advanced.sfMvcDlls += ,(Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcTestIntegrationDllPath)



        #Sitefinity Web App
        $_featherSettings.advanced.sfWebAppBinPath = Join-Path $_featherSettings.basic.Sitefinity_Web_App_Path $_featherSettings.constants.sfWebAppBinFolderName
        $_featherSettings.advanced.sfWebAppResourcePackagesPath = Join-Path $_featherSettings.basic.Sitefinity_Web_App_Path $_featherSettings.constants.sfWebAppResourcePackagesFolderName



        #Build Log
        $_featherSettings.advanced.buildLogFileLocation = Join-Path $_featherRootPath $_featherSettings.constants.buildLogFile
    }

    function Save-Settings {
        Log 'Saving settings...' White
        CreateNewFile $_settingsFileLocation (ConvertTo-Json $_featherSettings)
    }

    #Each time settings are loaded and updated to be up to date
    Load-Settings

    function Execute-Setup {
        Log '>>>>>>>>>> Setup Mode <<<<<<<<<<' Green

        Load-Settings

        Read-Settings

        Update-Settings

        Save-Settings

        Log '>>>>>>>>>> Settings Saved <<<<<<<<<<' Green
    }

    #endregion

    #region Update

    function Get-GitExe {
        IF (Test-Path $_featherSettings.system.GIT_EXE) {
            return $_featherSettings.system.GIT_EXE
        }
        ELSEIF(Test-Path $_featherSettings.system.GIT_EXE_BACKUP) {
            return $_featherSettings.system.GIT_EXE_BACKUP
        }
        ELSE {
            throw 'Git.exe could not be found on your computer. Check the feather-settings.json file under system key'
        }
    }

    function Git-Checkout {
        $checkoutResult = $False
        & (Get-GitExe) checkout -- . 2>&1 | % { $checkoutResult = $_ }
    }

    function Git-Stash {
        $gitStashResult = $False
        & (Get-GitExe) stash 2>&1 | % { $gitStashResult = $_ }

        IF($gitStashResult) {        
            IF($gitStashResult.GetType().Name -eq 'String' -and $gitStashResult.StartsWith('No local changes to save')) {
                Log '[Nothing to stash]' Yellow -NoNewLine $True
            }
            ELSEIF($gitStashResult.GetType().Name -eq 'Object[]' -and $gitStashResult.Get(0).StartsWith('Saved working directory')) {
                Log '[Changes stashed]' Yellow -NoNewLine $True
            }
            ELSEIF($gitStashResult.GetType().Name -eq 'String' -and $gitStashResult.StartsWith('HEAD is now at')) {
                Log '[Changes stashed]' Yellow -NoNewLine $True
            }
            ELSE {
                Log 'Error occured while executing git stash command !' Red
                IF($gitStashResult.Exception) {
                    throw $gitStashResult.Exception
                }
                ELSE {
                    throw $gitStashResult
                }
            }
        }
    }

    function Git-Status {
        $statusResult = $False
        & (Get-GitExe) status 2>&1 | % { $statusResult = $_ }

        IF($statusResult -and $statusResult.GetType().Name -eq 'String' -and $statusResult.StartsWith('no changes added to commit')) {
            throw 'You have uncommited changes. Save them or use stash or force'
        }
    }    

    function Git-CheckoutBranch {
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [System.String]$BranchToCheckout
        )

        $checkoutResult = $False
        & (Get-GitExe) checkout $BranchToCheckout 2>&1 | % { $checkoutResult = $_ }

        IF($checkoutResult -ne $False -and(-not $checkoutResult.ToString().StartsWith('Already')) -and(-not $checkoutResult.ToString().StartsWith('Your branch is up-to-date')) -and(-not $checkoutResult.ToString().StartsWith('Switched to branch'))) {
            throw $checkoutResult
        }
    }    

    function Git-Pull {
        param(
            [Parameter(Mandatory=$False, Position=0)]
            [System.String]$PullOptions
        )
        
        $gitPullResult = $False

        & (Get-GitExe) pull $PullOptions 2>&1 | % { $gitPullResult = $_ }

        IF($gitPullResult) {
            IF($gitPullResult.GetType().Name -eq 'String' -and $gitPullResult.StartsWith('Already up-to-date')) {
                Log '[Already up-to-date]' Green
            }
            ELSEIF($gitPullResult.GetType().Name -eq 'String') {
                Log "[$gitPullResult]" Green
            }
            ELSE {
                Log 'Error occured while executing git pull command !' Red
                IF($gitStashResult.Exception) {
                    throw $gitStashResult.Exception
                }
                ELSE {
                    throw $gitStashResult
                }
            }
        }
    }

    function Git-All {
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [System.String]$Path,
            
            [Parameter(Mandatory=$True, Position=1)]
            [System.Boolean]$UseStash,
            
            [Parameter(Mandatory=$True, Position=2)]
            [System.Boolean]$UseForce,
            
            [Parameter(Mandatory=$True, Position=3)]
            [System.String]$BranchToCheckout,

            [Parameter(Mandatory=$False, Position=4)]
            [System.Boolean]$UseCredentials,

            [Parameter(Mandatory=$False, Position=5)]
            [System.String]$ProjectToUpdate
        )

        Log "Updating $Path " White -NoNewLine $True
        
        $oldLocation = Get-Location

        Set-Location $Path

        TRY {
            IF($UseForce) {
                Git-Checkout
            }
            ELSEIF($UseStash) {
                Git-Stash
            }

            Git-Status
            
            Git-CheckoutBranch $BranchToCheckout

            $PullOptions = '';
            IF ($UseCredentials -and (Prompt 'Credentials are required for this repository. Do you want to specify username/password (otherwise the stored SSH keys will be used) ? ')) {
                $username = Read-Host 'Username for https://github.com'
                $password = Read-Host -AsSecureString  "Password for https://$username@github.com"
                $clearPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

                $PullOptions = 'https://'+ $username +':' + $clearPassword +'@github.com/Sitefinity/' + $ProjectToUpdate
            }

            Git-Pull $PullOptions
        }
        Finally {
            Set-Location $oldLocation
        }
    }
    
    function Execute-Update {
        param(
            [Parameter(Mandatory=$False, Position=0)]
            [System.String]$ProjectsToUpdate,

            [Parameter(Mandatory=$False, Position=1)]
            [System.String]$GitUpdateOption,

            [Parameter(Mandatory=$False, Position=2)]
            [System.String]$GitBranchOption
        )

        # Extracting Git options if any
        $useStash = $False
        $useForce = $False
        $branchToCheckout = 'master'

        IF(-not ([System.String]::IsNullOrEmpty($GitBranchOption))) {
             $branchToCheckout = $GitBranchOption
        }

        IF($GitUpdateOption.ToLower() -eq 'normal' -or [System.String]::IsNullOrEmpty($GitUpdateOption)) {
            Log '>>>>>>>>>> Executing Update <<<<<<<<<<' Green
        }
        ELSEIF($GitUpdateOption.ToLower() -eq 'stash') {
            Log '>>>>>>>>>> Executing Update ','[Stashing changes]',' <<<<<<<<<<' Green,Yellow,Green
            $useStash = $True
        }
        ELSEIF($GitUpdateOption.ToLower() -eq 'force') {
            Log '>>>>>>>>>> Executing Update ','[Forced]',' <<<<<<<<<<' Green,Red,Green
            $doForce = Prompt 'All unsaved changes in current branches will be deleted. Are you sure Y/N ?'
            IF($doForce) {
                $useForce = $True
            }
            ELSE {
                Log '>>>>>>>>>> Update Canceled <<<<<<<<<<' Yellow
                return
            }
        }        
        ELSE {
            throw "Unknown Git Option"
        }

        IF($ProjectsToUpdate.ToLower() -eq 'all') {
            Git-All $_featherSettings.basic.Sitefinity_Mvc_Project_Path $useStash $useForce $branchToCheckout $True sitefinity-mvc
            Git-All $_featherSettings.basic.Feather_Project_Path $useStash $useForce $branchToCheckout $False
            Git-All $_featherSettings.basic.Feather_Widgets_Project_Path $useStash $useForce $branchToCheckout $False
            Git-All $_featherSettings.basic.Feather_Packages_Project_Path $useStash $useForce $branchToCheckout $False
        }
        ELSEIF($ProjectsToUpdate.ToLower() -eq 'mvc') {
            Git-All $_featherSettings.basic.Sitefinity_Mvc_Project_Path $useStash $useForce $branchToCheckout $True sitefinity-mvc
        }
        ELSEIF($ProjectsToUpdate.ToLower() -eq 'feather') {
            Git-All $_featherSettings.basic.Feather_Project_Path $useStash $useForce $branchToCheckout $False
        }
        ELSEIF($ProjectsToUpdate.ToLower() -eq 'widgets') {
            Git-All $_featherSettings.basic.Feather_Widgets_Project_Path $useStash $useForce $branchToCheckout $False
        }
        ELSEIF($ProjectsToUpdate.ToLower() -eq 'packages') {
           Git-All $_featherSettings.basic.Feather_Packages_Project_Path $useStash $useForce $branchToCheckout $False
        }
        ELSE{
            throw 'Command not supported yet'
        }
       
        Log '>>>>>>>>>> Update Complete <<<<<<<<<<' Green
    }
    
    #endregion

    #region Build
    
    function Get-MsBuildExe {
        IF (Test-Path $_featherSettings.system.MS_BUILD_EXE) {
            return $_featherSettings.system.MS_BUILD_EXE
        }
        ELSEIF(Test-Path $_featherSettings.system.MS_BUILD_EXE_BACKUP) {
            return $_featherSettings.system.MS_BUILD_EXE_BACKUP
        }
        ELSE {
            throw 'MsBuild.exe could not be found on your computer. Check the feather-settings.json file under system key'
        }
    }

    function Build-Sln {
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [System.String]$SolutionPath,

            [Parameter(Mandatory=$False, Position=1)]
            [System.String]$BuildOpt
        )

        IF([System.String]::IsNullOrEmpty($BuildOpt) -or $BuildOpt.ToLower() -eq 'normal') {
            Log "[B]","uilding $SolutionPath ... " Yellow, White -NoNewLine $True
            TRY {
                & (Get-MsBuildExe) $SolutionPath /t:Build /p:Configuration=Debug | Out-File $_featherSettings.advanced.buildLogFileLocation
            }
            CATCH [System.Exception] {
                Log "[failed]"," - rebuilding ... " Yellow, White -NoNewLine $True
                & (Get-MsBuildExe) $SolutionPath /t:Clean /t:Build /p:Configuration=Debug | Out-File $_featherSettings.advanced.buildLogFileLocation
            }
        }
        ELSE {
            Log "[ReB]","uilding $SolutionPath ... " Yellow, White -NoNewLine $True
            & (Get-MsBuildExe) $SolutionPath /t:Clean /t:Build /p:Configuration=Debug | Out-File $_featherSettings.advanced.buildLogFileLocation
        }
                      
        if ($LastExitCode -ne 0) {
            throw "Building the solution $SolutionPath failed - check file ${_featherSettings.advanced.buildLogFileLocation} for more information"
        }
       
        Log "[Done]" Green
    }

    function CopyDlls-WebApp{
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [System.String[]]$DllsToCopy,

            [Parameter(Mandatory=$False, Position=1)]
            [System.String]$DllsNameForLog
        )
        Log "Copying ",$DllsNameForLog," Dlls to Sitefinity Web Application ... " White, Green, White -NoNewLine $True

        Foreach($fDll in $DllsToCopy) {
            Copy-Item $fDll $_featherSettings.advanced.sfWebAppBinPath -Force
        }

        Log "[Done]" Green
    }

    function CopyDlls-SfMvc-WebApp {
        CopyDlls-WebApp $_featherSettings.advanced.sfMvcDlls "Sf MVC"
    }

    function CopyDlls-Feather-WebApp {
        CopyDlls-WebApp $_featherSettings.advanced.featherDlls "Feather"
    }

    function CopyDlls-FeatherWidgets-WebApp {
        CopyDlls-WebApp $_featherSettings.advanced.featherWidgetsDlls "Widgets"
    }

    function Copy-FeatherPackages-WebApp {
        Log 'Copying Feather Packages to Sitefinity Web Application ... ' White -NoNewLine $True

        IF(-not (Test-Path $_featherSettings.advanced.sfWebAppResourcePackagesPath)) {
        New-Item -ItemType Directory -Force -Path $_featherSettings.advanced.sfWebAppResourcePackagesPath | Out-Null
        Log '[ResourcePackages folder created] ' Yellow -NoNewLine $True
        }
            
        $tooLongNameCount = 0

        Foreach($packageName in $_featherSettings.constants.featherPackagesFolderNames) {
        $fpPackageFolderPath = Join-Path $_featherSettings.basic.Feather_Packages_Project_Path $packageName
        $sfWebAppPackageFolderPath = Join-Path $_featherSettings.advanced.sfWebAppResourcePackagesPath $packageName

        Copy-Item ($fpPackageFolderPath + '\*') ($sfWebAppPackageFolderPath + '\') -Force -Recurse 2>&1 | % { $tooLongNameCount++ }
        }         

        IF($tooLongNameCount -eq 0) {
            Log "[Done]" Green
        }
        ELSE {
            Log "[$tooLongNameCount files have too long name] [Done]" Yellow 
        }
    }

    function Get-PackageLibPath {
        param(
            [Parameter(Mandatory=$True, Position=0)]
            [System.String]$ProjectPath,

            [Parameter(Mandatory=$True, Position=1)]
            [System.String]$PackageName
        )
        
        $packages = dir -Directory (Join-Path $ProjectPath 'packages') | Where-Object {$_.Name -match ($PackageName + '.\d')} | Sort-Object -Descending { $_.Name }
        IF ($packages.Length -gt 0) {
            $packagePath = $packages[0].FullName;

            IF (Test-Path (Join-Path $packages[0].FullName 'lib')) {
                $packagePath = Join-Path $packages[0].FullName 'lib';

                IF (Test-Path (Join-Path $packagePath 'net45')) {
                    return (Join-Path $packagePath 'net45');
                }
                ELSEIF(Test-Path (Join-Path $packagePath 'net40')) {
                    return (Join-Path $packagePath 'net40');
                }
            }
        }

        return '';
    }

    function UpdatePackages-SfMvc{
        $sfMvcDllPath = Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcDllPath
        $sfMvcTestUtilitiesDllPath = Join-Path $_featherSettings.basic.Sitefinity_Mvc_Project_Path $_featherSettings.constants.sfMvcTestUtilitiesDllPath

        # Feather
        $featherMvcPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.sfMvcPackageName
        $featherMvcTestUtilitiesPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.sfMvcTestUtilitiesPackageName
        
        Log "Updating ",$_featherSettings.constants.sfMvcPackageName," package in ", "Feather", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $sfMvcDllPath $featherMvcPackageDllPath -Force
        Log "[Done]" Green

        Log "Updating ",$_featherSettings.constants.sfMvcTestUtilitiesPackageName," package in ", "Feather", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $sfMvcTestUtilitiesDllPath $featherMvcTestUtilitiesPackageDllPath -Force
        Log "[Done]" Green

        # Widgets
        $featherWidgetsMvcPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.sfMvcPackageName
        $featherWidgetsMvcTestUtilitiesPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.sfMvcTestUtilitiesPackageName
        
        Log "Updating ",$_featherSettings.constants.sfMvcPackageName," package in ", "Feather Widgets", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $sfMvcDllPath $featherWidgetsMvcPackageDllPath -Force
        Log "[Done]" Green
        
        Log "Updating ",$_featherSettings.constants.sfMvcTestUtilitiesPackageName," package in ", "Feather Widgets", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $sfMvcTestUtilitiesDllPath $featherWidgetsMvcTestUtilitiesPackageDllPath -Force
        Log "[Done]" Green
    }

    function UpdatePackages-Feather{
        # featherPackageName featherTestUtilitiesPackageName
        $featherDllPath = Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherDllPath
        $featherTestUtilitiesDllPath = Join-Path $_featherSettings.basic.Feather_Project_Path $_featherSettings.constants.featherTestUtilitiesDllPath

        $featherPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.featherPackageName
        $featherTestUtilitiesPackageDllPath = Get-PackageLibPath $_featherSettings.basic.Feather_Widgets_Project_Path $_featherSettings.constants.featherTestUtilitiesPackageName
                
        Log "Updating ",$_featherSettings.constants.featherPackageName," package in ", "Feather Widgets", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $featherDllPath $featherPackageDllPath -Force
        Log "[Done]" Green
        
        Log "Updating ",$_featherSettings.constants.featherTestUtilitiesPackageName," package in ", "Feather Widgets", " ... " White, Green, White, Green, White -NoNewLine $True
        Copy-Item $featherTestUtilitiesDllPath $featherTestUtilitiesPackageDllPath -Force
        Log "[Done]" Green
    }

    function Execute-Build {
        param(
            [Parameter(Mandatory=$False, Position=0)]
            [System.String]$ProjectsToBuild,

            [Parameter(Mandatory=$False, Position=1)]
            [System.String]$BuildOptionToUse
        )

        Log '>>>>>>>>>> Executing Build <<<<<<<<<<' Green

        IF($ProjectsToBuild.ToLower() -eq 'all') {
            Build-Sln $_featherSettings.advanced.sfMvcSolutionPath $BuildOptionToUse
            CopyDlls-SfMvc-WebApp

            # Update Mvc package befor building Feather and Feather widgets
            UpdatePackages-SfMvc

            Build-Sln $_featherSettings.advanced.featherSolutionPath $BuildOptionToUse
            CopyDlls-Feather-WebApp

            # Update Feather package before building Feather widgets
            UpdatePackages-Feather

            Build-Sln $_featherSettings.advanced.featherWidgetsSolutionPath $BuildOptionToUse
            CopyDlls-FeatherWidgets-WebApp

            Copy-FeatherPackages-WebApp
        }
        ELSEIF($ProjectsToBuild.ToLower() -eq 'mvc') {
            Build-Sln $_featherSettings.advanced.sfMvcSolutionPath $BuildOptionToUse
            CopyDlls-SfMvc-WebApp
        }
        ELSEIF($ProjectsToBuild.ToLower() -eq 'feather') {
            Build-Sln $_featherSettings.advanced.featherSolutionPath $BuildOptionToUse
            CopyDlls-Feather-WebApp
        }
        ELSEIF($ProjectsToBuild.ToLower() -eq 'widgets') {
            Build-Sln $_featherSettings.advanced.featherWidgetsSolutionPath $BuildOptionToUse
            CopyDlls-FeatherWidgets-WebApp
        }
        ELSEIF($ProjectsToBuild.ToLower() -eq 'packages') {
            Copy-FeatherPackages-WebApp
        }
        ELSE{
            throw 'Command not supported yet'
        }
        
        Log '>>>>>>>>>> Build Complete <<<<<<<<<<' Green
    }
    
    #endregion

    #region Copy

    function Execute-Copy {
        param(
            [Parameter(Mandatory=$False, Position=0)]
            [System.String]$ProjectsToCopy
        )

        Log '>>>>>>>>>> Executing Copy <<<<<<<<<<' Green

        IF($ProjectsToCopy.ToLower() -eq 'all') {
            CopyDlls-SfMvc-WebApp
            CopyDlls-Feather-WebApp
            CopyDlls-FeatherWidgets-WebApp
            Copy-FeatherPackages-WebApp
        }
        ELSEIF($ProjectsToCopy.ToLower() -eq 'mvc') {
            CopyDlls-SfMvc-WebApp
        }
        ELSEIF($ProjectsToCopy.ToLower() -eq 'feather') {
            CopyDlls-Feather-WebApp
        }
        ELSEIF($ProjectsToCopy.ToLower() -eq 'widgets') {
            CopyDlls-FeatherWidgets-WebApp
        }
        ELSEIF($ProjectsToCopy.ToLower() -eq 'packages') {
            Copy-FeatherPackages-WebApp
        }
        ELSE{
            throw 'Command not supported yet'
        }

        Log '>>>>>>>>>> Copying Complete <<<<<<<<<<' Green
    }

    #endregion

    #region Execution

    Write-Host

    IF ($Command.ToLower() -eq 'setup') {
        Execute-Setup
    }
    ELSEIF ($Command.ToLower() -eq 'update') {
        IF([System.String]::IsNullOrEmpty($ProjectsOption)) {
            $ProjectsOption = PromptProjectsOption "Which project [all / feather / widgets / packages / mvc] ? "
        }

        Execute-Update $ProjectsOption $GitOption $GitBranch
    }
    ELSEIF ($Command.ToLower() -eq 'build') {
        IF([System.String]::IsNullOrEmpty($ProjectsOption)) {
            $ProjectsOption = PromptProjectsOption "Which project [all / feather / widgets / packages / mvc] ? "
        }

        Execute-Build $ProjectsOption $BuildOption
    }
    ELSEIF ($Command.ToLower() -eq 'copy') {
        IF([System.String]::IsNullOrEmpty($ProjectsOption)) {
            $ProjectsOption = PromptProjectsOption "Which project [all / feather / widgets / packages / mvc] ? "
        }

        Execute-Copy $ProjectsOption
    }
    ELSEIF ($Command.ToLower() -eq 'magic') {
        IF([System.String]::IsNullOrEmpty($ProjectsOption)) {
            $ProjectsOption = PromptProjectsOption "Which project [all / feather / widgets / packages / mvc] ? "
        }

        Execute-Update $ProjectsOption $GitOption $GitBranch
        Execute-Build $ProjectsOption $BuildOption
    }
    ELSE {
        throw 'Command not supported yet'
    }

    #endregion
}

IF($_featherRootPath -eq $False) {
    $_featherRootPath = (Get-Location).Path.ToString()
    feather setup
}
