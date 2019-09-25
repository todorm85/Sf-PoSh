. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    
    Describe "sf-_switchStyleCop" {
        
        $expectedOn = @(
            "  <!-- Define StyleCopEnabled property. -->",
                "  <PropertyGroup Condition=""('`$(SourceAnalysisEnabled)' != '') and ('`$(StyleCopEnabled)' == '')"">",
                "    <StyleCopEnabled>`$(SourceAnalysisEnabled)</StyleCopEnabled>",
                "  </PropertyGroup>",
                "  <PropertyGroup Condition=""'`$(StyleCopEnabled)' == ''"">",
                "    <StyleCopEnabled>true</StyleCopEnabled>",
                "  </PropertyGroup>"
        )

        $expectedOff = @(
            "  <!-- Define StyleCopEnabled property. -->",
                "  <PropertyGroup Condition=""('`$(SourceAnalysisEnabled)' != '') and ('`$(StyleCopEnabled)' == '')"">",
                "    <StyleCopEnabled>false</StyleCopEnabled><!-- source analysis prop line -->",
                "  </PropertyGroup>",
                "  <PropertyGroup Condition=""'`$(StyleCopEnabled)' == ''"">",
                "    <StyleCopEnabled>false</StyleCopEnabled>",
                "  </PropertyGroup>"
        )

        $Script:result = ''
        Mock _writeFile {
            $Script:result = $content
        }

        it "disables style cop task correctly" {
            Mock Get-Content {
                $expectedOn
            }

            _switchStyleCop -enable:$false

            $Script:result.Count | Should -BeExactly $expectedOff.Count

            for ($i=0; $i -lt $Script:result.Count; $i++) {
                $Script:result[$i].Trim() | Should -Be $expectedOff[$i].Trim()
            }
        }

        it "enables style cop taks correctly" {
            Mock Get-Content {
                $expectedOff
            }

            _switchStyleCop -enable:$true

            $Script:result.Count | Should -BeExactly $expectedOn.Count

            for ($i=0; $i -lt $Script:result.Count; $i++) {
                $Script:result[$i].Trim() | Should -Be $expectedOn[$i].Trim()
            }
        }
    }
}
