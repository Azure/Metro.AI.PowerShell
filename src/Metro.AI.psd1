@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Metro.AI.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

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
    RequiredModules   = @(
        @{
            ModuleName    = 'Az.Accounts'
            ModuleVersion = '5.1.0'
        }
    )

    # List of all files packaged with this module that have a .ps1xml extension.
    FormatsToProcess = @('Metro.AI.Format.ps1xml')

    # Functions to export from this module.
    FunctionsToExport = @(
        'Invoke-MetroAIUploadFile',
        'Clear-MetroAIContextCache',
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
        'Remove-MetroAIThread',
        'Invoke-MetroAIMessage',
        'Start-MetroAIThreadRun',
        'Get-MetroAIThreadRunStatus',
        'Get-MetroAIMessage',
        'Start-MetroAIThreadWithMessages',
        'Add-MetroAIAgentOpenAPIDefinition',
        'Set-MetroAIContext',
        'Get-MetroAIContext',
        'New-MetroAIConversation',
        'Invoke-MetroAIConversation',
        'Get-MetroAIConversation',
        'Remove-MetroAIConversation',
        'Get-MetroAIResponse',
        'Remove-MetroAIResponse'
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
