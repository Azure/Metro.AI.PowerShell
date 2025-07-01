#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test runner for Metro.AI PowerShell Module
.DESCRIPTION
    This script runs Pester tests for the Metro.AI PowerShell module with different configurations.
.PARAMETER TestType
    Type of tests to run: All, Unit, SmokeTest, Integration
.PARAMETER OutputFormat
    Output format for test results: NUnitXml, JUnitXml, Console
.PARAMETER OutputPath
    Path to save test results file
.PARAMETER PassThru
    Return the test results object
.PARAMETER Show
    What to show during test execution: All, Failed, Passed, Pending, Skipped, Inconclusive
.EXAMPLE
    ./Run-Tests.ps1 -TestType Unit
    Run only unit tests
.EXAMPLE
    ./Run-Tests.ps1 -TestType SmokeTest -OutputFormat NUnitXml -OutputPath "./TestResults.xml"
    Run smoke tests and save results to XML file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Unit", "SmokeTest", "Integration")]
    [string]$TestType = "All",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("NUnitXml", "JUnitXml", "Console")]
    [string]$OutputFormat = "Console",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$PassThru,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Failed", "Passed", "Pending", "Skipped", "Inconclusive")]
    [string]$Show = "All"
)

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error "Pester module is not installed. Please install it with: Install-Module -Name Pester -Force"
    exit 1
}

# Import Pester
Import-Module Pester -Force

# Set up test directory
$TestDirectory = $PSScriptRoot
Write-Host "Test Directory: $TestDirectory" -ForegroundColor Green

# Define test configuration
$PesterConfiguration = [PesterConfiguration]::Default
$PesterConfiguration.Run.PassThru = $true  # Always enable PassThru for summary

# Configure output
switch ($OutputFormat) {
    "NUnitXml" {
        $PesterConfiguration.TestResult.Enabled = $true
        $PesterConfiguration.TestResult.OutputFormat = "NUnitXml"
        if ($OutputPath) {
            $PesterConfiguration.TestResult.OutputPath = $OutputPath
        }
        else {
            $PesterConfiguration.TestResult.OutputPath = Join-Path $TestDirectory "TestResults.xml"
        }
    }
    "JUnitXml" {
        $PesterConfiguration.TestResult.Enabled = $true
        $PesterConfiguration.TestResult.OutputFormat = "JUnitXml"
        if ($OutputPath) {
            $PesterConfiguration.TestResult.OutputPath = $OutputPath
        }
        else {
            $PesterConfiguration.TestResult.OutputPath = Join-Path $TestDirectory "TestResults.xml"
        }
    }
    "Console" {
        $PesterConfiguration.TestResult.Enabled = $false
    }
}

# Configure what to show
switch ($Show) {
    "All" { $PesterConfiguration.Output.Verbosity = "Detailed" }
    "Failed" { $PesterConfiguration.Output.Verbosity = "Normal" }
    "Passed" { $PesterConfiguration.Output.Verbosity = "Normal" }
    default { $PesterConfiguration.Output.Verbosity = "Normal" }
}

# Configure tags based on test type
$TestPaths = @()
switch ($TestType) {
    "Unit" {
        $PesterConfiguration.Filter.Tag = @("Unit")
        $TestPaths = @(Join-Path $TestDirectory "Metro.AI.UnitTests.ps1")
        Write-Host "Running Unit Tests..." -ForegroundColor Yellow
    }
    "SmokeTest" {
        $PesterConfiguration.Filter.Tag = @("SmokeTest")
        $TestPaths = @(Join-Path $TestDirectory "Metro.AI.SmokeTests.ps1")
        Write-Host "Running Smoke Tests..." -ForegroundColor Yellow
        Write-Host "Note: Smoke tests require a valid Metro.AI context to be configured." -ForegroundColor Cyan
    }
    "Integration" {
        $PesterConfiguration.Filter.Tag = @("Integration")
        $TestPaths = @(Join-Path $TestDirectory "Metro.AI.SmokeTests.ps1")
        Write-Host "Running Integration Tests..." -ForegroundColor Yellow
        Write-Host "Note: Integration tests require a valid Metro.AI context to be configured." -ForegroundColor Cyan
    }
    "All" {
        $TestPaths = @(
            Join-Path $TestDirectory "Metro.AI.UnitTests.ps1",
            Join-Path $TestDirectory "Metro.AI.SmokeTests.ps1"
        )
        Write-Host "Running All Tests..." -ForegroundColor Yellow
        Write-Host "Note: Some tests require a valid Metro.AI context to be configured." -ForegroundColor Cyan
    }
}

# Set the test paths
$PesterConfiguration.Run.Path = $TestPaths

# Check if Metro.AI context is available for integration tests
if ($TestType -in @("SmokeTest", "Integration", "All")) {
    try {
        Import-Module (Join-Path $TestDirectory ".." "src" "Metro.AI.psd1") -Force
        $context = Get-MetroAIContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Warning "Metro.AI context is not configured. Integration and Smoke tests may fail."
            Write-Host "To configure context, run: Set-MetroAIContext -Endpoint 'your-endpoint' -ApiType 'Agent|Assistant'" -ForegroundColor Cyan
        }
        else {
            Write-Host "Metro.AI context detected: $($context.Endpoint)" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Could not verify Metro.AI context: $_"
    }
}

# Run the tests
Write-Host "Starting test execution..." -ForegroundColor Green
Write-Host "Test Type: $TestType" -ForegroundColor Gray
Write-Host "Output Format: $OutputFormat" -ForegroundColor Gray
if ($OutputPath) {
    Write-Host "Output Path: $OutputPath" -ForegroundColor Gray
}
Write-Host ""

try {
    $TestResults = Invoke-Pester -Configuration $PesterConfiguration
    
    # Display summary
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Green
    if ($TestResults) {
        Write-Host "Total Tests: $($TestResults.TotalCount)" -ForegroundColor Gray
        Write-Host "Passed: $($TestResults.PassedCount)" -ForegroundColor Green
        Write-Host "Failed: $($TestResults.FailedCount)" -ForegroundColor Red
        Write-Host "Skipped: $($TestResults.SkippedCount)" -ForegroundColor Yellow
        Write-Host "Duration: $($TestResults.Duration)" -ForegroundColor Gray
        
        if ($TestResults.FailedCount -gt 0) {
            Write-Host ""
            Write-Host "Some tests failed. Review the output above for details." -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host ""
            Write-Host "All tests passed successfully!" -ForegroundColor Green
            exit 0
        }
    }
    else {
        Write-Host "Test execution completed but no results returned." -ForegroundColor Yellow
        exit 0
    }
    
}
catch {
    Write-Error "Test execution failed: $_"
    exit 1
}
