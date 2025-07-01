# Metro.AI PowerShell Module Test Suite

This directory contains comprehensive tests for the Metro.AI PowerShell module, including unit tests, integration tests, and smoke tests.

## Test Structure

```
Tests/
├── README.md                    # This file
├── Run-Tests.ps1               # Test runner script
├── TestConfig.ps1              # Test configuration and utilities
├── Metro.AI.UnitTests.ps1      # Unit tests (no external dependencies)
├── Metro.AI.SmokeTests.ps1     # Smoke tests (require live endpoint)
└── TestData/                   # Test data files
    └── sample.txt              # Sample file for upload tests
```

## Test Categories

### Unit Tests (`Metro.AI.UnitTests.ps1`)
- **Purpose**: Test module structure, function signatures, parameter validation
- **Dependencies**: None (can run without Metro.AI context)
- **Coverage**: 
  - Module import and export verification
  - Function parameter validation
  - Help documentation verification
  - Private function isolation
  - Basic error handling

### Smoke Tests (`Metro.AI.SmokeTests.ps1`)
- **Purpose**: Test all public functions against a live Metro.AI endpoint
- **Dependencies**: Requires configured Metro.AI context
- **Coverage**:
  - Context management functions
  - Resource CRUD operations
  - Thread management and messaging
  - File upload and management
  - API integration functions
  - Alias functionality

## Prerequisites

### Required Software
1. **PowerShell 7.0+**
2. **Pester 5.0+** - Install with: `Install-Module -Name Pester -Force`
3. **Metro.AI Module** - Must be importable from `../src/Metro.AI.psd1`

### Configuration for Integration Tests
For smoke tests and integration tests, you need a configured Metro.AI context:

```powershell
# Set up your Metro.AI context
Set-MetroAIContext -Endpoint "https://your-endpoint.com" -ApiType "Agent"  # or "Assistant"
```

## Running Tests

### Using the Test Runner (Recommended)

```powershell
# Run all tests
./Tests/Run-Tests.ps1

# Run only unit tests (no external dependencies)
./Tests/Run-Tests.ps1 -TestType Unit

# Run smoke tests (requires configured context)
./Tests/Run-Tests.ps1 -TestType SmokeTest

# Run tests with XML output
./Tests/Run-Tests.ps1 -TestType All -OutputFormat NUnitXml -OutputPath "./TestResults.xml"
```

#

## Contributing to Tests

When adding new functions to the module:

1. **Add unit tests** in `Metro.AI.UnitTests.ps1`:
   - Verify function is exported
   - Test parameter validation
   - Check help documentation

2. **Add smoke tests** in `Metro.AI.SmokeTests.ps1`:
   - Test against live endpoint
   - Include cleanup logic
   - Handle expected failures gracefully

3. **Update test configuration** in `TestConfig.ps1`:
   - Add new test data if needed
   - Update cleanup functions

## CI/CD Integration

The test runner script supports XML output formats suitable for CI/CD pipelines:

```powershell
# For Azure DevOps
./Run-Tests.ps1 -OutputFormat NUnitXml -OutputPath "TestResults.xml"

# For GitHub Actions
./Run-Tests.ps1 -OutputFormat JUnitXml -OutputPath "test-results.xml"
```
