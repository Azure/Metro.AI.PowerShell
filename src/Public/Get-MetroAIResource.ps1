function Get-MetroAIResource {
    <#
        .SYNOPSIS
            Retrieves details of Metro AI resources (Agent or Assistant).
        .DESCRIPTION
            This function queries the specified Metro AI service endpoint to retrieve resource details. If an AgentId is provided, it returns details for that specific resource; otherwise, it returns a collection of all available resources based on the ApiType.
        .PARAMETER AgentId
            (Optional) The unique identifier of a specific agent/assistant resource to retrieve. If not provided, the function returns all available resources.
        .EXAMPLE
            Get-MetroAIResource -AgentId "resource-123" -Endpoint "https://example.azure.com" -ApiType Agent
        .EXAMPLE
            Get-MetroAIResource -Endpoint "https://example.azure.com" -ApiType Assistant
        .NOTES
            When an AgentId is provided, the function returns the detailed resource object; otherwise, it returns an array of resource summaries.
    #>
    [Alias("Get-MetroAIAgent")]
    [Alias("Get-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Alias('AssistantId', 'ResourceId')]
        [string]$AgentId
    )
    try {
        $path = $AgentId
        $result = Invoke-MetroAIApiCall -Service 'agents' -Operation 'get' -Path $path -Method Get
        
        if ($PSBoundParameters['AgentId'] -or $PSBoundParameters['AssistantId'] -or $PSBoundParameters['ResourceId']) {
            if ($result -and $result -is [System.Management.Automation.PSCustomObject]) {
                if (-not $result.PSTypeNames.Contains('Metro.AI.Resource')) {
                    $result.PSTypeNames.Insert(0, 'Metro.AI.Resource')
                }
            }
            return $result
        }
        
        $allItems = @()
        $currentResult = $result

        while ($true) {
            $list = $null
            if ($currentResult.PSObject.Properties.Name -contains 'value') {
                $list = $currentResult.value
            }
            elseif ($currentResult.PSObject.Properties.Name -contains 'data') {
                $list = $currentResult.data
            }

            if ($list) {
                $allItems += $list
            }
            elseif ($currentResult -is [System.Management.Automation.PSCustomObject]) {
                # Fallback for single object or weird structure, though unlikely in list mode
                $allItems += $currentResult
            }

            # Handle 'nextLink' pagination (Azure standard)
            if ($currentResult.PSObject.Properties.Name -contains 'nextLink' -and -not [string]::IsNullOrWhiteSpace($currentResult.nextLink)) {
                Write-Verbose "Fetching next page from $($currentResult.nextLink)"
                $currentResult = Invoke-MetroAIApiCall -FullUri $currentResult.nextLink -Method Get
            }
            # Handle 'has_more' / 'last_id' pagination (OpenAI/Foundry standard)
            elseif ($currentResult.PSObject.Properties.Name -contains 'has_more' -and $currentResult.has_more -eq $true -and $currentResult.last_id) {
                Write-Verbose "Fetching next page after $($currentResult.last_id)"
                
                # Construct the next URI manually since we need to append query params
                # Base endpoint + /agents + api-version + after
                # We assume the default api-version if not set in context
                $ver = if ($script:MetroContext.ApiVersion) { $script:MetroContext.ApiVersion } else { '2025-11-15-preview' }
                # Use centralized URI resolution logic to construct the next page URI
                $query = @{ 'api-version' = $ver; 'after' = $currentResult.last_id }
                $currentResult = Invoke-MetroAIApiCall -Service 'agents' -Operation 'list' -Query $query -Method Get
            }
            else {
                break
            }
        }
        
        if ($allItems.Count -gt 0) {
            return ($allItems | ForEach-Object {
                if ($_ -is [System.Management.Automation.PSCustomObject]) {
                    if (-not $_.PSTypeNames.Contains('Metro.AI.Resource')) {
                        $_.PSTypeNames.Insert(0, 'Metro.AI.Resource')
                    }
                }
                $_
            })
        }
        else {
            return $null
        }
    }
    catch {
        Write-Error "Get-MetroAIResource error: $_"
    }
}
