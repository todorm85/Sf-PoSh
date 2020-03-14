. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Comparing versions should" {
        It "return false when first is higher" {
            $f = "1.1.11"
            $s = "1.1.0"
            _isFirstVersionLower $f $s | Should -BeFalse
            $f = "2.1.1"
            $s = "1.1.11"
            _isFirstVersionLower $f $s | Should -BeFalse
            $f = "1.2.1"
            $s = "1.1.11"
            _isFirstVersionLower $f $s | Should -BeFalse
        }
        It "return true when first is lower" {
            $f = "1.1.0"
            $s = "1.1.11"
            _isFirstVersionLower $f $s | Should -BeTrue
            $f = "2.1.1"
            $s = "1.1.11"
            _isFirstVersionLower $s $f | Should -BeTrue
            $f = "1.2.1"
            $s = "1.1.11"
            _isFirstVersionLower $s $f | Should -BeTrue
        }
        It "return false when equal" {
            $f = "1.1.0"
            $s = "1.1.0"
            _isFirstVersionLower $f $s | Should -BeFalse
        }
        It "throw when invalid input" {
            $f = "1.1.0"
            { _isFirstVersionLower $f $s } | Should -Throw
            $f = "1.1.0"
            $s = ""
            { _isFirstVersionLower $f $s } | Should -Throw
            $f = "1.1.0"
            $s = "1.1.1.1"
            { _isFirstVersionLower $f $s } | Should -Throw
            $f = "1.1.0"
            $s = "1.1"
            { _isFirstVersionLower $f $s } | Should -Throw
            $f = "1.1.0"
            $s = "1"
            { _isFirstVersionLower $f $s } | Should -Throw
        }
    }

    Describe "When upgrading" {
        Mock _getNewModuleVersion { "10.0.0" }
        $root = (Get-PSDrive TestDrive).Root
        $GLOBAL:sf.Config.dataPath = "$root\db.xml"
        It "from undefined version should invoke all scripts" {
            "<?xml version=""1.0""?>
            <data defaultTagsFilter=""t3 t4"" version=""45eaf024-ebaf-421b-9166-26018cbd0fdf"">
              <sitefinities>
              </sitefinities>
              <containers defaultContainerName="""" />
            </data>" | Out-File -FilePath $GLOBAL:sf.config.dataPath
            $Script:executionCount = 0
            $script:actual = -1
            $scripts = @(
                { 
                    Param($v)
                    $v | Should -Be "0.0.0"
                    $script:actual = $v
                },
                { 
                    Param($v)
                    $v | Should -Be "0.0.0"
                }
            )

            upgrade $scripts
            $script:actual | Should -Be "0.0.0"
        }

        It "from defined version should invoke only scripts for later versions" {
            "<?xml version=""1.0""?>
            <data defaultTagsFilter=""t3 t4"" version=""45eaf024-ebaf-421b-9166-26018cbd0fdf"" moduleVersion=""5.5.11"">
              <sitefinities>
              </sitefinities>
              <containers defaultContainerName="""" />
            </data>" | Out-File -FilePath $GLOBAL:sf.config.dataPath
            $Script:executionCount = 0
            $scripts = @(
                { 
                    Param($v)
                    if (_isFirstVersionLower $v "6.5.1") {
                        $Script:executionCount += 1
                    }
                },
                { 
                    Param($v)
                    if (_isFirstVersionLower $v "4.5.1") {
                        $Script:executionCount += 1
                    }
                }
            )

            upgrade $scripts
            $Script:executionCount | Should -Be 1
        }
        It "failing to get the new module version should not execute any scripts and throw" {
            Mock _getNewModuleVersion { }
            { upgrade $scripts } | Should -Throw
        }
    }

    It "getting module version should return value" {
        _getNewModuleVersion | Should -Match "^\d+\.\d+\.\d+$"
        @(_getNewModuleVersion) | Should -HaveCount 1
    }
}