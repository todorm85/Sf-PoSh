. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    function get-project {
        param (
            [string]$tags
        )
        $proj = [SfProject]::new([Guid]::NewGuid())
        $proj.tags = $tags
        $proj
    }

    Describe "filter-projectsByTags should" {
        It "show only untagged when passing '+'" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
            )

            $result = filter-projectsByTags -sitefinities $projects -tagsFilter "+"
            $result | Should -HaveCount 2
        }
        It "filter included tags correctly" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
                get-project -tags 'another'
            )

            $result = filter-projectsByTags -sitefinities $projects -tagsFilter "another"
            $result | Should -HaveCount 2
        }
        It "filter excluded tags correctly" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
                get-project -tags 'another'
            )

            $result = filter-projectsByTags -sitefinities $projects -tagsFilter "-another"
            $result | Should -HaveCount 3
        }
        It "filter excluded multi tags correctly" {
            $projects = @(
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'one'
                get-project -tags 'test'
                get-project -tags 'another'
                get-project -tags 'another'
            )

            $result = filter-projectsByTags -sitefinities $projects -tagsFilter "-another -test"
            $result | Should -HaveCount 3
        }
        It "filter multi tags correctly" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another test'
                get-project -tags 'one'
                get-project -tags 'another'
                get-project -tags 'another'
            )

            $result = filter-projectsByTags -sitefinities $projects -tagsFilter "another -test"
            $result | Should -HaveCount 2
        }
    }
}