@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Metro.AI.psm1'

    # Version number of this module.
    ModuleVersion     = '0.3.0'

    # GUID used to uniquely identify this module.
    GUID              = '09e3e9c9-b7b7-4449-a5e1-a026bbc7c8fb'

    # Author of the module.
    Author            = 'SWAT'

    # Company or vendor of the module.
    CompanyName       = 'Microsoft'

    # Description of the functionality provided by the module.
    Description       = 'Unified PowerShell module for Azure AI Agent and Assistant APIs '

    # Minimum version of the Windows PowerShell engine required by this module.
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module.
    RequiredModules   = @('Az.Accounts')

    # Functions to export from this module.
    FunctionsToExport = @(
        'Invoke-MetroAIUploadFile',
        'Get-MetroAIOutputFiles',
        'Remove-MetroAIFiles',
        'New-MetroAIResource',
        'Get-MetroAIResource',
        'Invoke-MetroAIApiCall',
        'Remove-MetroAIResource',
        'Set-MetroAIResource',
        'Set-MetroAIResource',
        'New-MetroAIFunction',
        'New-MetroAIThread',
        'Get-MetroAIThread',
        'Invoke-MetroAIMessage',
        'Start-MetroAIThreadRun',
        'Get-MetroAIThreadStatus',
        'Get-MetroAIMessages',
        'Start-MetroAIThreadWithMessages',
        'Add-MetroAIAgentOpenAPIDefinition',
        'Set-MetroAIContext',
        'Get-MetroAIContext'
    )

    AliasesToExport   = @(
        'Get-MetroAIAgent',
        'Get-MetroAIAssistant',
        'Set-MetroAIAgent',
        'Set-MetroAIAssistant',
        'New-MetroAIAgent',
        'New-MetroAIAssistant',
        'Remove-MetroAIAgent',
        'Remove-MetroAIAssistant'
    )

    # Private data to pass to the module.
    PrivateData       = @{
        PSData = @{
            Tags       = @('Metropolis', 'Azure', 'Agent', 'Assistant')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/Azure/Metro.AI.PowerShell'
        }
    }
}
