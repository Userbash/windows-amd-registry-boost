# To run these tests, you need to have the Pester module installed.
# Install it by running: Install-Module -Name Pester -Force -SkipPublisherCheck

# Import the functions from the script to be tested
. "$PSScriptRoot\amd_optimizer.ps1"

# Import test data
$testData = Get-Content -Path "$PSScriptRoot\test-data.json" | ConvertFrom-Json

# Start of the test suite
Describe 'amd_optimizer.ps1 Tests' -Tags 'Unit' {

    # Mock all external commands and cmdlets to ensure a safe, isolated environment
    BeforeAll {
        # Mock registry cmdlets
        Mock Get-ItemProperty { 
            # This complex mock allows tests to set up a mock registry state
            if ($script:mockRegistry.ContainsKey($args[0])) {
                return $script:mockRegistry[$args[0]][$args[2]]
            }
            return $null
        }
        Mock Set-ItemProperty { # Do nothing, just record the call
        }
        Mock New-Item { # Do nothing, just record the call
        }
        Mock Remove-ItemProperty { # Do nothing, just record the call
        }
        Mock Get-ChildItem {
            # Simulate the directory structure for GPU detection
            $keyNames = $script:mockRegistry.Keys | Where-Object { $_.StartsWith($args[1]) }
            $childItems = foreach ($key in $keyNames) {
                [pscustomobject]@{ PSChildName = ($key -split '\')[-1] }
            }
            return $childItems
        }

        # Mock system commands
        Mock Checkpoint-Computer { # Do nothing
        }
        Mock reg { # Do nothing, just record the call
        }
        Mock Test-Path {
            param($Path)
            return $script:mockFileSystem.ContainsKey($Path)
        }


        # Mock user interaction
        Mock Read-Host {
            param($Prompt)
            return $script:mockUserInput
        }
        Mock Write-Host { # Suppress output during tests
        }
        Mock Write-Error { # Suppress output
        }
        Mock Write-Warning { # Suppress output
        }

        # Mock other system interactions
        Mock pause { }
        Mock exit { throw "exit" } # Throw an exception to stop execution in tests
        Mock Clear-Host { }
    }

    Context 'Get-AmdGpu' {
        # Iterate through the test cases from the JSON file
        foreach ($testCase in $testData.GpuDetection) {
            It "should correctly handle scenario: $($testCase.Scenario)" {
                # Setup the mock registry for this specific test case
                $script:mockRegistry = $testCase.MockRegistry | ConvertTo-Hashtable -Deep

                $result = Get-AmdGpu
                $result | Should -Be $testCase.ExpectedResult
            }
        }
    }

    Context 'Manage-Backup' {
        foreach ($testCase in $testData.ManageBackup) {
            It "should correctly handle scenario: $($testCase.Scenario)" {
                InModuleScope -ModuleName 'Pester' -ScriptBlock {
                    Mock reg {}
                    Mock Test-Path { param($Path) ; if ($Path -like '*backup_amd_settings.reg') { return $using:testCase.BackupFileExists } }
                    $script:mockUserInput = $testCase.UserChoice
                    
                    if ($testCase.ExpectedAction -eq 'Restore') {
                        Mock reg { param($command, $path) ; if($command -eq 'import') { return $using:testCase.RegImportExitCode } }
                        
                        if ($testCase.RegImportExitCode -eq 0) {
                            { Manage-Backup -GpuKey "HKLM:\FAKE\GPU" } | Should -Throw 'exit'
                        } else {
                            { Manage-Backup -GpuKey "HKLM:\FAKE\GPU" } | Should -Throw 'exit'
                        }
                        Assert-MockCalled reg -ParameterFilter { $command -eq 'import' } -Exactly 1
                    }

                    if ($testCase.ExpectedAction -eq 'Backup') {
                         Manage-Backup -GpuKey "HKLM:\FAKE\GPU"
                         Assert-MockCalled reg -ParameterFilter { $command -eq 'export' } -Exactly 1
                    }
                }
            }
        }
    }

    Context 'Test-Admin' {
        It 'should return $true when running as Administrator' {
            Mock (New-Object Security.Principal.WindowsPrincipal).IsInRole { return $true }
            Test-Admin | Should -Be $true
        }

        It 'should return $false when not running as Administrator' {
            Mock (New-Object Security.Principal.WindowsPrincipal).IsInRole { return $false }
            Test-Admin | Should -Be $false
        }
    }
    
    Context 'New-RestorePoint' {
        It 'should call Checkpoint-Computer' {
            New-RestorePoint
            Assert-MockCalled Checkpoint-Computer -Times 1 -Exactly
        }

        It 'should handle errors when Checkpoint-Computer fails (Demonic)' {
            Mock Checkpoint-Computer { throw "Cannot create restore point" }
            # This test just ensures the function doesn't crash.
            # In a real environment, you'd check for the warning message.
            { New-RestorePoint } | Should -Not -Throw
        }
    }

    Context 'Show-Menu' {
        It 'should return the correct choices based on user input' {
            # Simulate user input for the prompts in Show-Menu
            $script:mockUserInput = "1"
            
            $choices = Show-Menu
            $choices.Overlay | Should -Be "1"
            $choices.GpuSeries | Should -Be "1"
        }
    }

    Context 'Apply-Tweaks' {
        # Iterate through the test cases from the JSON file
        foreach ($testCase in $testData.ApplyTweaks) {
            It "should apply correct tweaks for scenario: $($testCase.Scenario)" {
                InModuleScope -ModuleName 'Pester' -ScriptBlock {
                    Mock Set-ItemProperty {}
                    Mock Remove-ItemProperty {}

                    # Setup a mock registry if the test case defines one
                    if ($null -ne $testCase.MockRegistryState) {
                        $script:mockRegistry = $testCase.MockRegistryState | ConvertTo-Hashtable -Deep
                    } else {
                        $script:mockRegistry = @{} # Ensure it's clean otherwise
                    }
                }
                
                Apply-Tweaks -GpuKey "HKLM:\FAKE\GPU\0000" -UserChoices $testCase.UserChoices
                
                # Verify that the correct properties were set
                if($testCase.ExpectedProperties) {
                    foreach ($prop in $testCase.ExpectedProperties) {
                        Assert-MockCalled Set-ItemProperty -AtLeast 1 -Scope It -ParameterFilter {
                            $Name -eq $prop.Name -and $Value -eq $prop.Value
                        }
                    }
                }

                # Verify that the correct properties were removed
                if($testCase.RemovedProperties) {
                    foreach ($prop in $testCase.RemovedProperties) {
                        Assert-MockCalled Remove-ItemProperty -Exactly 1 -Scope It -ParameterFilter {
                            $Name -eq $prop
                        }
                    }
                }

                # Demonic Test: Verify Set-ItemProperty is called with -Force to overwrite incorrect types
                if ($testCase.Scenario -like '*Demonic*') {
                    Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ParameterFilter {
                        $Name -eq 'EnableUlps' -and $Force -eq $true
                    }
                }
            }
        }
    }
}

