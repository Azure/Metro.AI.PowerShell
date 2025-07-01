# Test Configuration for Metro.AI PowerShell Module
# This file contains configuration settings for running Pester tests

# Test configuration object
$script:TestConfig = @{
    # Module path
    ModulePath = Join-Path $PSScriptRoot ".." "src" "Metro.AI.psd1"
    
    # Test categories
    Categories = @{
        Unit = "Unit"
        Integration = "Integration" 
        SmokeTest = "SmokeTest"
    }
    
    # Test data for smoke tests
    TestData = @{
        # Sample test message
        TestMessage = "This is a test message from Pester tests"
        
        # Sample resource data
        SampleResource = @{
            name = "PesterTestResource"
            description = "A test resource created by Pester tests"
            instructions = "You are a helpful test assistant"
        }
        
        # Sample function definition
        SampleFunction = @{
            name = "get_test_data"
            description = "A test function that returns sample data"
            parameters = @{
                type = "object"
                properties = @{
                    query = @{
                        type = "string"
                        description = "The test query parameter"
                    }
                }
                required = @("query")
            }
        }
        
        # Sample thread data
        SampleThread = @{
            messages = @(
                @{
                    role = "user"
                    content = "Hello, this is a test message"
                }
            )
        }
        
        # File upload test data
        TestFilePath = Join-Path $PSScriptRoot "TestData" "sample.txt"
    }
    
    # Cleanup settings
    Cleanup = @{
        # Whether to clean up test resources after tests
        EnableCleanup = $true
        
        # Resources created during tests (will be populated during test runs)
        CreatedResources = @()
        CreatedThreads = @()
        UploadedFiles = @()
    }
    
    # Test timeouts
    Timeouts = @{
        ShortOperation = 30    # seconds
        MediumOperation = 60   # seconds
        LongOperation = 120    # seconds
    }
}

# Function to get test configuration
function Get-TestConfig {
    return $script:TestConfig
}

# Function to add created resource for cleanup
function Add-TestResource {
    param([string]$ResourceId, [string]$Type)
    
    $script:TestConfig.Cleanup.CreatedResources += @{
        Id = $ResourceId
        Type = $Type
        CreatedAt = Get-Date
    }
}

# Function to add created thread for cleanup
function Add-TestThread {
    param([string]$ThreadId)
    
    $script:TestConfig.Cleanup.CreatedThreads += @{
        Id = $ThreadId
        CreatedAt = Get-Date
    }
}

# Function to add uploaded file for cleanup
function Add-TestFile {
    param([string]$FileId)
    
    $script:TestConfig.Cleanup.UploadedFiles += @{
        Id = $FileId
        CreatedAt = Get-Date
    }
}
