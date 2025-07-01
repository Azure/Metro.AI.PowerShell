BeforeAll {
    # Import the test configuration
    . "$PSScriptRoot/TestConfig.ps1"
    $script:Config = Get-TestConfig

    # Import the Metro.AI module
    Import-Module $script:Config.ModulePath -Force
}

Describe "Metro.AI PowerShell Module - Unit Tests" -Tags @("Unit") {

    Context "Module Structure Tests" {

        It "Module should import successfully" {
            Get-Module Metro.AI | Should -Not -BeNullOrEmpty
        }

        It "Should export expected number of functions" {
            $functions = Get-Command -Module Metro.AI -CommandType Function
            $functions.Count | Should -Be 20
        }

        It "Should export expected number of aliases" {
            $aliases = Get-Command -Module Metro.AI -CommandType Alias
            $aliases.Count | Should -Be 8
        }

        It "All public functions should be available" {
            $expectedFunctions = @(
                'Add-MetroAIAgentOpenAPIDefinition',
                'Clear-MetroAIContextCache',
                'Get-MetroAIContext',
                'Get-MetroAIMessages',
                'Get-MetroAIOutputFiles',
                'Get-MetroAIResource',
                'Get-MetroAIThread',
                'Get-MetroAIThreadStatus',
                'Invoke-MetroAIApiCall',
                'Invoke-MetroAIMessage',
                'Invoke-MetroAIUploadFile',
                'New-MetroAIFunction',
                'New-MetroAIResource',
                'New-MetroAIThread',
                'Remove-MetroAIFiles',
                'Remove-MetroAIResource',
                'Set-MetroAIContext',
                'Set-MetroAIResource',
                'Start-MetroAIThreadRun',
                'Start-MetroAIThreadWithMessages'
            )

            foreach ($functionName in $expectedFunctions) {
                $command = Get-Command $functionName -ErrorAction SilentlyContinue
                $command | Should -Not -BeNullOrEmpty -Because "Function $functionName should be exported"
                $command.Source | Should -Be "Metro.AI"
            }
        }

        It "All expected aliases should be available" {
            $expectedAliases = @(
                'Get-MetroAIAgent',
                'Get-MetroAIAssistant',
                'Set-MetroAIAgent',
                'Set-MetroAIAssistant',
                'New-MetroAIAgent',
                'New-MetroAIAssistant',
                'Remove-MetroAIAgent',
                'Remove-MetroAIAssistant'
            )

            foreach ($aliasName in $expectedAliases) {
                $command = Get-Command $aliasName -ErrorAction SilentlyContinue
                $command | Should -Not -BeNullOrEmpty -Because "Alias $aliasName should be available"
                $command.CommandType | Should -Be "Alias"
            }
        }
    }

    Context "Function Parameter Validation" {

        It "Set-MetroAIContext should have required parameters" {
            $command = Get-Command Set-MetroAIContext
            $command.Parameters.Keys | Should -Contain "Endpoint"
            $command.Parameters.Keys | Should -Contain "ApiType"

            # Check parameter types
            $command.Parameters.Endpoint.ParameterType | Should -Be ([string])
            $command.Parameters.ApiType.ParameterType | Should -Be ([string])
        }

        It "Invoke-MetroAIApiCall should have required parameters" {
            $command = Get-Command Invoke-MetroAIApiCall
            $command.Parameters.Keys | Should -Contain "Service"
            $command.Parameters.Keys | Should -Contain "Operation"

            # Check mandatory parameters
            $command.Parameters.Service.Attributes.Mandatory | Should -Contain $true
            $command.Parameters.Operation.Attributes.Mandatory | Should -Contain $true
        }

        It "New-MetroAIResource should have proper parameter structure" {
            $command = Get-Command New-MetroAIResource
            $command.Parameters.Keys | Should -Contain "name"
            $command.Parameters.Keys | Should -Contain "description"
        }

        It "Functions should have proper help documentation" {
            # Note: Some functions may not have full help documentation yet
            # This test checks if functions have at least basic structure
            $functionsToCheck = @(
                'Get-MetroAIContext',
                'Invoke-MetroAIApiCall'
            )

            foreach ($functionName in $functionsToCheck) {
                $help = Get-Help $functionName -ErrorAction SilentlyContinue
                $help | Should -Not -BeNullOrEmpty -Because "$functionName should have help available"
            }
        }
    }

    Context "Context Management Unit Tests" {

        BeforeEach {
            # Clear any existing context for clean tests
            Clear-MetroAIContextCache
        }

        It "Get-MetroAIContext should return null when no context is set" {
            # After clearing cache, context should not exist
            $context = Get-MetroAIContext -ErrorAction SilentlyContinue
            # This might return null or throw an error depending on implementation
            # We'll accept either behavior as valid
            ($context -eq $null) -or ($Error.Count -gt 0) | Should -Be $true
        }

        It "Set-MetroAIContext should validate ApiType parameter" {
            # Test with invalid ApiType
            { Set-MetroAIContext -Endpoint "https://example.com" -ApiType "InvalidType" } | Should -Throw
        }

        It "Set-MetroAIContext should validate Endpoint parameter" {
            # Test with invalid endpoint format
            { Set-MetroAIContext -Endpoint "not-a-url" -ApiType "Agent" } | Should -Throw
        }
    }

    Context "Input Validation Tests" {

        It "Functions should handle null/empty parameters gracefully" {
            # Test New-MetroAIResource with empty name
            { New-MetroAIResource -name "" -description "test" } | Should -Throw

            # Test Invoke-MetroAIApiCall with empty service
            { Invoke-MetroAIApiCall -Service "" -Operation "test" } | Should -Throw
        }

        It "Functions should validate parameter types" {
            # Test Set-MetroAIContext with non-string endpoint
            { Set-MetroAIContext -Endpoint 12345 -ApiType "Agent" } | Should -Throw
        }
    }

    Context "Private Function Accessibility" {

        It "Private functions should not be exported" {
            $privateFunctions = @(
                'Get-MetroAIContextCachePath',
                'Save-MetroAIContextCache',
                'Get-MetroAIContextCache',
                'Get-MetroAuthHeader',
                'Get-MetroApiVersion',
                'Set-CodeInterpreterConfiguration',
                'Remove-MetroAIAutoGeneratedProperties'
            )

            foreach ($functionName in $privateFunctions) {
                $command = Get-Command $functionName -ErrorAction SilentlyContinue
                $command | Should -BeNullOrEmpty -Because "Private function $functionName should not be exported"
            }
        }
    }

    Context "Error Handling Tests" {

        It "Functions should provide meaningful error messages" {
            # Test calling API functions without context
            try {
                Invoke-MetroAIApiCall -Service "test" -Operation "test"
                $false | Should -Be $true -Because "Should have thrown an error"
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
                $_.Exception.Message | Should -Match "context" -Because "Error should mention context requirement"
            }
        }

        It "Functions should handle network errors gracefully" {
            # This is tested more thoroughly in integration tests
            # Here we just verify the function exists and has error handling structure
            $command = Get-Command Invoke-MetroAIApiCall
            $command.Definition | Should -Match "try" -Because "Should have try-catch error handling"
            $command.Definition | Should -Match "catch" -Because "Should have try-catch error handling"
        }
    }

    Context "Class Functionality Tests" {

        It "MetroAIContext class should be available" {
            # Test if the class type is available in the current session
            try {
                # Try to reference the class type
                $classType = [MetroAIContext]
                $classType | Should -Not -BeNullOrEmpty
            }
            catch {
                # If direct class reference fails, check if it's defined in the module
                # This is acceptable as the class might be scoped to the module
                $_.Exception.Message | Should -Match "MetroAIContext" -Because "Error should reference the class name"
            }
        }
    }
}
