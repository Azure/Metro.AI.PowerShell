# Test Configuration for Metro.AI PowerShell Module
# This file contains configuration settings for running Pester tests

# Test configuration object
$script:TestConfig = @{
    # Module path
    ModulePath = Join-Path $PSScriptRoot ".." "src" "Metro.AI.psd1"

    # Test categories
    Categories = @{
        Unit        = "Unit"
        Integration = "Integration"
        SmokeTest   = "SmokeTest"
    }

    # Test data for smoke tests
    TestData   = @{
        # Sample test message
        TestMessage               = "This is a test message from Pester tests"

        # Sample resource data
        SampleResource            = @{
            model        = "gpt-4.1"  # Required parameter for New-MetroAIResource
            name         = "PesterTestResource"
            description  = "A test resource created by Pester tests"
            instructions = "You are a helpful test assistant"
        }

        # Sample agent data for comprehensive testing
        SampleAgent               = @{
            name         = "PesterTestAgent"
            model        = "gpt-4.1"  # Updated to match README examples
            description  = "A test agent created by Pester tests"
            instructions = @"
You are a helpful assistant for testing purposes. Your task is to assist with test queries and provide relevant information.
You should always be polite and respectful. If you do not know the answer to a question, you should say so.
Always ask clarifying questions if the user's request is unclear.
"@
            temperature  = 0.7  # Add consistent temperature setting
        }

        # Alternative models for fallback testing
        AlternativeModels         = @("gpt-4", "gpt-4-turbo", "gpt-35-turbo")

        # Sample specialized agents with proper model specification
        SpecializedAgentTemplates = @{
            "ResearchAgent" = @{
                model        = "gpt-4.1"
                name         = "PesterResearchAgent"
                description  = "Test research agent with web search capabilities"
                instructions = "You are a research assistant for testing purposes. Help users find and analyze information."
                temperature  = 0.5
            }
            "CodeAgent"     = @{
                model        = "gpt-4.1"
                name         = "PesterCodeAgent"
                description  = "Test code analysis agent"
                instructions = "You are a code analysis assistant for testing. Help users understand and improve their code."
                temperature  = 0.3
            }
            "BusinessAgent" = @{
                model        = "gpt-4.1"
                name         = "PesterBusinessAgent"
                description  = "Test business intelligence agent"
                instructions = "You are a business intelligence assistant for testing. Help analyze data and provide insights."
                temperature  = 0.6
            }
        }

        # Sample function definition
        SampleFunction            = @{
            name        = "get_test_data"
            description = "A test function that returns sample data"
            parameters  = @{
                type       = "object"
                properties = @{
                    query = @{
                        type        = "string"
                        description = "The test query parameter"
                    }
                }
                required   = @("query")
            }
        }

        # Sample thread data
        SampleThread              = @{
            messages = @(
                @{
                    role    = "user"
                    content = "Hello, this is a test message"
                }
            )
        }

        # Sample MCP server configurations for testing
        SampleMcpServers          = @(
            @{
                server_label     = 'TestWeatherAPI'
                server_url       = 'https://weather.example.com/mcp'
                require_approval = 'never'
            },
            @{
                server_label     = 'TestDatabaseAPI'
                server_url       = 'https://db.example.com/mcp'
                allowed_tools    = @('query_data', 'get_info')
                require_approval = 'never'
            }
        )

        # Sample specialized agents for orchestration testing
        SpecializedAgents         = @{
            "TestMarketAgent"     = @{
                "Model"        = "gpt-4.1"
                "Description"  = "Test agent that provides market data analysis"
                "Instructions" = "Provide market data and analysis for testing purposes"
                "Temperature"  = 0.5
            }
            "TestResearchAgent"   = @{
                "Model"        = "gpt-4.1"
                "Description"  = "Test agent that conducts research"
                "Instructions" = "Conduct research and provide insights for testing"
                "Temperature"  = 0.6
            }
            "TestComplianceAgent" = @{
                "Model"        = "gpt-4.1"
                "Description"  = "Test agent for compliance checking"
                "Instructions" = "Ensure compliance with regulations for testing purposes"
                "Temperature"  = 0.3
            }
        }

        # Complex test messages for advanced scenarios
        ComplexTestMessages       = @{
            WebSearch      = "Please search for recent information about PowerShell best practices"
            DataAnalysis   = "Can you help me analyze this data and provide insights?"
            MultiAgent     = "I need help with market analysis, research, and compliance checks"
            FileProcessing = "Please analyze the uploaded file and provide a summary"
        }

        # File upload test data
        TestFilePath              = Join-Path $PSScriptRoot "TestData" "sample.txt"
    }

    # Cleanup settings
    Cleanup    = @{
        # Whether to clean up test resources after tests
        EnableCleanup    = $true

        # Resources created during tests (will be populated during test runs)
        CreatedResources = @()
        CreatedThreads   = @()
        UploadedFiles    = @()
    }

    # Test timeouts
    Timeouts   = @{
        ShortOperation  = 30    # seconds
        MediumOperation = 60   # seconds
        LongOperation   = 120    # seconds
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
        Id        = $ResourceId
        Type      = $Type
        CreatedAt = Get-Date
    }
}

# Function to add created thread for cleanup
function Add-TestThread {
    param([string]$ThreadId)

    $script:TestConfig.Cleanup.CreatedThreads += @{
        Id        = $ThreadId
        CreatedAt = Get-Date
    }
}

# Function to add uploaded file for cleanup
function Add-TestFile {
    param([string]$FileId)

    $script:TestConfig.Cleanup.UploadedFiles += @{
        Id        = $FileId
        CreatedAt = Get-Date
    }
}
