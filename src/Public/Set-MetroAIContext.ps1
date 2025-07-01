function Set-MetroAIContext {
    [CmdletBinding(DefaultParameterSetName = 'Endpoint')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Endpoint')]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,

        [Parameter(Mandatory, ParameterSetName = 'ConnectionString')]
        [string]$ConnectionString,

        [string]$ApiVersion,

        [switch]$SkipValidation,

        [switch]$NoCache
    )

    if ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
        Write-Verbose "Setting context from connection string"
        $script:MetroContext = [MetroAIContext]::new($ConnectionString, $ApiType, $true)
    }
    else {
        Write-Verbose "Setting context for endpoint $Endpoint"
        $script:MetroContext = [MetroAIContext]::new($Endpoint, $ApiType, $ApiVersion)
    }

    # Validate the context by attempting to retrieve resources
    if (-not $SkipValidation) {
        Write-Verbose "Validating context by attempting to retrieve resources"
        try {
            $null = Get-MetroAIResource -ErrorAction Stop
            Write-Verbose "Context validation successful"
        }
        catch {
            # Clear the invalid context
            $script:MetroContext = $null
            throw "Failed to validate Metro AI context. Please check your endpoint, connection string, and API type. Error: $($_.Exception.Message)"
        }
    }

    # Save to cache unless NoCache is specified
    if (-not $NoCache) {
        Save-MetroAIContextCache -Context $script:MetroContext
    }

    Write-verbose "Metro AI context set for $ApiType API at $($script:MetroContext.Endpoint)"
}
