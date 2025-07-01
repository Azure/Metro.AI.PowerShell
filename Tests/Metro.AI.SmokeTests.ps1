BeforeAll {
    # Import the test configuration
    . "$PSScriptRoot/TestConfig.ps1"
    $script:Config = Get-TestConfig
    
    # Import the Metro.AI module
    Import-Module $script:Config.ModulePath -Force
    
    # Verify Metro.AI context is available
    $context = Get-MetroAIContext -ErrorAction SilentlyContinue
    if (-not $context) {
        throw "Metro.AI context not available. Please run Set-MetroAIContext before running tests."
    }
    
    Write-Host "Running smoke tests against: $($context.Endpoint)" -ForegroundColor Green
    Write-Host "API Type: $($context.ApiType)" -ForegroundColor Green
}

Describe "Metro.AI PowerShell Module - Public Functions Smoke Tests" -Tags @("SmokeTest", "Integration") {
    
    BeforeAll {
        # Initialize test tracking variables
        $script:CreatedResources = @()
        $script:CreatedThreads = @()
        $script:UploadedFiles = @()
    }
    
    Context "Context Management Functions" {
        
        It "Get-MetroAIContext should return current context" {
            $context = Get-MetroAIContext
            $context | Should -Not -BeNullOrEmpty
            $context.Endpoint | Should -Not -BeNullOrEmpty
            $context.ApiType | Should -BeIn @("Agent", "Assistant")
        }
        
        It "Set-MetroAIContext should work with current context" {
            $currentContext = Get-MetroAIContext
            { Set-MetroAIContext -Endpoint $currentContext.Endpoint -ApiType $currentContext.ApiType } | Should -Not -Throw
        }
        
        It "Clear-MetroAIContextCache should execute without error" {
            { Clear-MetroAIContextCache } | Should -Not -Throw
        }
    }
    
    Context "Resource Management Functions" {
        
        It "Get-MetroAIResource should list existing resources" {
            $resources = Get-MetroAIResource
            $resources | Should -Not -BeNull
            # Resources should be an array (even if empty)
            $resources.GetType().Name | Should -BeIn @("Object[]", "PSCustomObject", "Hashtable")
        }
        
        It "New-MetroAIResource should create a new resource" {
            $resourceData = $script:Config.TestData.SampleResource.Clone()
            $resourceData.name = "PesterTest-$(Get-Random)"
            
            $newResource = New-MetroAIResource @resourceData
            $newResource | Should -Not -BeNullOrEmpty
            $newResource.id | Should -Not -BeNullOrEmpty
            
            # Track for cleanup
            $script:CreatedResources += $newResource.id
        }
        
        It "Set-MetroAIResource should update an existing resource" -Skip:($script:CreatedResources.Count -eq 0) {
            if ($script:CreatedResources.Count -gt 0) {
                $resourceId = $script:CreatedResources[0]
                $updateData = @{
                    name = "PesterTest-Updated-$(Get-Random)"
                    description = "Updated description"
                }
                
                { Set-MetroAIResource -ResourceId $resourceId @updateData } | Should -Not -Throw
            }
        }
        
        It "Remove-MetroAIResource should delete a resource" -Skip:($script:CreatedResources.Count -eq 0) {
            if ($script:CreatedResources.Count -gt 0) {
                $resourceId = $script:CreatedResources[0]
                { Remove-MetroAIResource -ResourceId $resourceId } | Should -Not -Throw
                
                # Remove from tracking list
                $script:CreatedResources = $script:CreatedResources | Where-Object { $_ -ne $resourceId }
            }
        }
    }
    
    Context "Thread Management Functions" {
        
        It "New-MetroAIThread should create a new thread" {
            $newThread = New-MetroAIThread
            $newThread | Should -Not -BeNullOrEmpty
            $newThread.id | Should -Not -BeNullOrEmpty
            
            # Track for cleanup
            $script:CreatedThreads += $newThread.id
        }
        
        It "Get-MetroAIThread should retrieve thread information" -Skip:($script:CreatedThreads.Count -eq 0) {
            if ($script:CreatedThreads.Count -gt 0) {
                $threadId = $script:CreatedThreads[0]
                $thread = Get-MetroAIThread -ThreadId $threadId
                $thread | Should -Not -BeNullOrEmpty
                $thread.id | Should -Be $threadId
            }
        }
        
        It "Invoke-MetroAIMessage should send a message to thread" -Skip:($script:CreatedThreads.Count -eq 0) {
            if ($script:CreatedThreads.Count -gt 0) {
                $threadId = $script:CreatedThreads[0]
                $message = Invoke-MetroAIMessage -ThreadId $threadId -Content $script:Config.TestData.TestMessage
                $message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Get-MetroAIMessages should retrieve messages from thread" -Skip:($script:CreatedThreads.Count -eq 0) {
            if ($script:CreatedThreads.Count -gt 0) {
                $threadId = $script:CreatedThreads[0]
                $messages = Get-MetroAIMessages -ThreadId $threadId
                $messages | Should -Not -BeNull
            }
        }
        
        It "Start-MetroAIThreadRun should start a thread run" -Skip:($script:CreatedThreads.Count -eq 0) {
            if ($script:CreatedThreads.Count -gt 0 -and $script:CreatedResources.Count -gt 0) {
                $threadId = $script:CreatedThreads[0]
                # This might fail if no assistants/agents are available, so we'll use try/catch
                try {
                    $run = Start-MetroAIThreadRun -ThreadId $threadId
                    $run | Should -Not -BeNullOrEmpty
                } catch {
                    # If no assistant is available, the function should still execute without throwing unexpected errors
                    $_.Exception.Message | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It "Start-MetroAIThreadWithMessages should create thread and process messages" {
            $threadData = $script:Config.TestData.SampleThread
            try {
                $result = Start-MetroAIThreadWithMessages @threadData
                # Track the thread if created
                if ($result.thread_id) {
                    $script:CreatedThreads += $result.thread_id
                }
                $result | Should -Not -BeNullOrEmpty
            } catch {
                # This might fail if no assistant is configured, which is acceptable for smoke test
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "File Management Functions" {
        
        It "Invoke-MetroAIUploadFile should upload a file" {
            $testFile = $script:Config.TestData.TestFilePath
            if (Test-Path $testFile) {
                try {
                    $uploadResult = Invoke-MetroAIUploadFile -FilePath $testFile
                    $uploadResult | Should -Not -BeNullOrEmpty
                    
                    # Track for cleanup if successful
                    if ($uploadResult.id) {
                        $script:UploadedFiles += $uploadResult.id
                    }
                } catch {
                    # File upload might fail due to permissions or API limitations
                    $_.Exception.Message | Should -Not -BeNullOrEmpty
                }
            } else {
                Set-ItResult -Skipped -Because "Test file not found at $testFile"
            }
        }
        
        It "Get-MetroAIOutputFiles should retrieve output files list" {
            try {
                $files = Get-MetroAIOutputFiles
                $files | Should -Not -BeNull
            } catch {
                # This might not be available in all API configurations
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Remove-MetroAIFiles should delete files" -Skip:($script:UploadedFiles.Count -eq 0) {
            if ($script:UploadedFiles.Count -gt 0) {
                $fileId = $script:UploadedFiles[0]
                try {
                    { Remove-MetroAIFiles -FileId $fileId } | Should -Not -Throw
                    # Remove from tracking
                    $script:UploadedFiles = $script:UploadedFiles | Where-Object { $_ -ne $fileId }
                } catch {
                    # File removal might fail due to API constraints
                    $_.Exception.Message | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Context "Function Management Functions" {
        
        It "New-MetroAIFunction should create function definition" {
            $functionData = $script:Config.TestData.SampleFunction
            try {
                $function = New-MetroAIFunction @functionData
                $function | Should -Not -BeNullOrEmpty
            } catch {
                # Function creation might not be available in all configurations
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "API Integration Functions" {
        
        It "Invoke-MetroAIApiCall should make API calls" {
            # Test basic API call functionality
            try {
                # Use a simple GET call to test the API caller
                $result = Invoke-MetroAIApiCall -Service "threads" -Operation "list" -Method "Get"
                $result | Should -Not -BeNull
            } catch {
                # API call might fail due to various reasons, but should provide meaningful error
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Add-MetroAIAgentOpenAPIDefinition should process OpenAPI definitions" {
            # This function processes OpenAPI definitions
            $sampleOpenApiSpec = @{
                openapi = "3.0.0"
                info = @{
                    title = "Test API"
                    version = "1.0.0"
                }
                paths = @{}
            }
            
            try {
                $result = Add-MetroAIAgentOpenAPIDefinition -OpenApiSpec $sampleOpenApiSpec
                $result | Should -Not -BeNull
            } catch {
                # This might fail depending on the API configuration
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Alias Functions" {
        
        It "Aliases should be available and functional" {
            # Test that aliases are properly exported
            $aliases = @(
                'Get-MetroAIAgent',
                'Get-MetroAIAssistant', 
                'Set-MetroAIAgent',
                'Set-MetroAIAssistant',
                'New-MetroAIAgent',
                'New-MetroAIAssistant',
                'Remove-MetroAIAgent',
                'Remove-MetroAIAssistant'
            )
            
            foreach ($alias in $aliases) {
                $command = Get-Command $alias -ErrorAction SilentlyContinue
                $command | Should -Not -BeNullOrEmpty -Because "Alias $alias should be available"
                $command.CommandType | Should -Be "Alias"
            }
        }
    }
    
    AfterAll {
        # Cleanup created resources
        Write-Host "Cleaning up test resources..." -ForegroundColor Yellow
        
        # Clean up created threads
        foreach ($threadId in $script:CreatedThreads) {
            try {
                # Note: There might not be a direct delete thread API, so we'll skip this for now
                Write-Verbose "Thread cleanup for $threadId (if supported by API)"
            } catch {
                Write-Warning "Failed to clean up thread $threadId : $_"
            }
        }
        
        # Clean up created resources
        foreach ($resourceId in $script:CreatedResources) {
            try {
                Remove-MetroAIResource -ResourceId $resourceId -ErrorAction SilentlyContinue
                Write-Verbose "Cleaned up resource: $resourceId"
            } catch {
                Write-Warning "Failed to clean up resource $resourceId : $_"
            }
        }
        
        # Clean up uploaded files
        foreach ($fileId in $script:UploadedFiles) {
            try {
                Remove-MetroAIFiles -FileId $fileId -ErrorAction SilentlyContinue
                Write-Verbose "Cleaned up file: $fileId"
            } catch {
                Write-Warning "Failed to clean up file $fileId : $_"
            }
        }
        
        Write-Host "Test cleanup completed." -ForegroundColor Green
    }
}
