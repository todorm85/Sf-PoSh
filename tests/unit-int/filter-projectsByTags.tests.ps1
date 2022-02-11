. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    function get-project {
        param (
            [string]$tags
        )

        $proj = _newSfProjectObject -id "$([System.Guid]::NewGuid().ToString())"
        if ($null -eq $tags) {
            $proj.tags = $null
        }
        else {
            $proj.tags = [Collections.Generic.List[string]]($tags.Split(' '))
        }

        $proj
    }

    Describe "sf-project-tags-filter should" {
        It "show only untagged when passing '+u'" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
            )

            $result = $projects | sf-project-tags-filter -tagsFilter "+u"
            $result | Should -HaveCount 2
        }
        It "show all when passing none" {
            $projects = @(
                get-project -tags 'test'
                get-project -tags ''
                get-project -tags $null
                get-project -tags 'another'
                get-project -tags 'another another'
            )

            $result = $projects | sf-project-tags-filter
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

            $result = $projects | sf-project-tags-filter -tagsFilter "another"
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

            $result = $projects | sf-project-tags-filter -tagsFilter "_another"
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

            $result = $projects | sf-project-tags-filter -tagsFilter @("_another", "_test")
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

            $result = $projects | sf-project-tags-filter -tagsFilter @("another", "_test")
            $result | Should -HaveCount 2
        }
    }
}
