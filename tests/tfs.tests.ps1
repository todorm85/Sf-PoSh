Import-Module sf-dev

InModuleScope sf-dev {
    . "${PSScriptRoot}\init-tests.ps1"
    
    Describe "tfs-get-workspaces" {

        It "return names of all workspaces" {
            Mock tf-query-workspaces {
                "Collection: http://tfsemea.progress.com:8080/defaultcollection"
                "Workspace   Owner            Computer Comment"
                "----------- ---------------- -----"
                "test1    Todor Mitskovski TMITSKOV"
                "instance_0  Todor Mitskovski TMITSKOV"
                "instance_12 Todor Mitskovski TMITSKOV"
                "Tools       Todor Mitskovski TMITSKOV"
            }

            $projects = tfs-get-workspaces
            $projects | Should -HaveCount 4
            $projects[0] | Should -Be "test1"
        }

        It "No workspaces return empty collection" {
            Mock tf-query-workspaces {
                "Collection: http://tfsemea.progress.com:8080/defaultcollection"
                "Workspace   Owner            Computer Comment"
                "----------- ---------------- -----"
            }
            
            $projects = tfs-get-workspaces
            $projects | Should -Be $null
        }

        It "One workspace returns array with workspace" {
            Mock tf-query-workspaces {
                "Collection: http://tfsemea.progress.com:8080/defaultcollection"
                "Workspace   Owner            Computer Comment"
                "----------- ---------------- -----"
                "test1    Todor Mitskovski TMITSKOV"
            }
            
            $projects = tfs-get-workspaces
            $projects | Should -HaveCount 1
        }

        clean-testDb

    }

    Describe "tf-query-workspaces" {
        It "not throw" {
            { tf-query-workspaces } | Should -Not -Throw
        }

        It "return one line output correctly" {
            Mock execute-native { "line1" }
            $res = tf-query-workspaces
            $res | Should -Be "line1"
        }

        It "return multiple lines result correctly" {
            Mock execute-native { 
                "line1" 
                "line2"
            }
            
            $res = tf-query-workspaces
            $res | Should -HaveCount 2
            $res[1] | Should -Be "line2"
        }
    }

    Describe "tfs-create-workspace" {
        Mock Set-Location { }
        Mock tfs-delete-workspace { }
        Mock execute-native { }

        It "creates workspace correctly" {
            { tfs-create-workspace "testName" "dummy path" } | Should -Not -Throw
            Assert-MockCalled tfs-delete-workspace -Times 0
        }

        Context "workspace creation fails" {
            Mock execute-native { throw 'dummy' } -ParameterFilter { $command -and $command.Contains("/new") }

            It "stops execution" {
                { tfs-create-workspace "testName" "dummy path" } | Should -Throw "dummy"
                Assert-MockCalled execute-native -Times 1 -ParameterFilter { $command -and $command.Contains("/new")}
                Assert-MockCalled execute-native -Times 0 -ParameterFilter { $command -and $command.Contains("/unmap")}
                Assert-MockCalled tfs-delete-workspace -Times 0
            }
        }

        Context "unmapping default path fails" {
            Mock execute-native { throw 'dummy' } -ParameterFilter { $command -and $command.Contains("/unmap") }

            { tfs-create-workspace "testName" "dummy path" } | Should -Throw "WORKSPACE NOT CREATED!"

            It "tries to delete workspace" {
                Assert-MockCalled execute-native -Times 1 -ParameterFilter { $command -and $command.Contains("/new")}
                Assert-MockCalled execute-native -Times 1 -ParameterFilter { $command -and $command.Contains("/unmap")}
                Assert-MockCalled tfs-delete-workspace -Times 1
            }
        }

        Context "unmapping default path fails and delete workfold fails" {
            Mock execute-native { throw 'dummy' } -ParameterFilter { $command -and $command.Contains("/unmap") }
            Mock tfs-delete-workspace { throw "delete failed" } 

            { tfs-create-workspace "testName" "dummy path" } | Should -Throw "Workspace created but... "

            It "tries to delete workspace" {
                Assert-MockCalled execute-native -Times 1 -ParameterFilter { $command -and $command.Contains("/new")}
                Assert-MockCalled execute-native -Times 1 -ParameterFilter { $command -and $command.Contains("/unmap")}
                Assert-MockCalled tfs-delete-workspace -Times 1
            }
        }
    }
}