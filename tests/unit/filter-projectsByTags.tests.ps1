. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    function get-project {
        param (
            [string]$tags
        )

        $proj = _newSfProjectObject -id "$([System.Guid]::NewGuid().ToString())"
        $proj.tags = $tags
        $proj
    }

    Describe "_filterProjectsByTags should" {
        It "show only untagged when passing '+u'" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
            )

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "+u"
            $result | Should -HaveCount 2
        }
        It "show all when passing '+a'" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
                get-project -tags 'another another'
            )

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "+a"
            $result | Should -HaveCount 5
        }
        It "filter included tags correctly" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
                get-project -tags 'another'
            )

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "another"
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

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "-another"
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

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "-another -test"
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

            $result = _filterProjectsByTags -sitefinities $projects -tagsFilter "another -test"
            $result | Should -HaveCount 2
        }
    }
}
