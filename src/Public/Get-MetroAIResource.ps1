function Get-MetroAIResource {
    <#
        .SYNOPSIS
            Retrieves details of Metro AI resources (Agent or Assistant).
        .DESCRIPTION
            This function queries the specified Metro AI service endpoint to retrieve resource details. If an AssistantId is provided, it returns details for that specific resource; otherwise, it returns a collection of all available resources based on the ApiType.
        .PARAMETER AssistantId
            (Optional) The unique identifier of a specific assistant resource to retrieve. If not provided, the function returns all available resources.
        .EXAMPLE
            Get-MetroAIResource -AssistantId "resource-123" -Endpoint "https://example.azure.com" -ApiType Agent
        .EXAMPLE
            Get-MetroAIResource -Endpoint "https://example.azure.com" -ApiType Assistant
        .NOTES
            When an AssistantId is provided, the function returns the detailed resource object; otherwise, it returns an array of resource summaries.
    #>
    [Alias("Get-MetroAIAgent")]
    [Alias("Get-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string]$AssistantId
    )
    try {
        $path = $AssistantId
        $result = Invoke-MetroAIApiCall -Service 'assistants' -Operation 'get' -Path $path -Method Get
        if ($PSBoundParameters['AssistantId']) { return $result } else { return $result.data }
    }
    catch {
        Write-Error "Get-MetroAIResource error: $_"
    }
}
