function New-MetroAIConversation {
    <#
        .SYNOPSIS
            Creates a new conversation using the Foundry Agents preview Responses API.
        .DESCRIPTION
            Calls POST /openai/conversations with the configured endpoint/api-version in the current Metro context.
        .EXAMPLE
            New-MetroAIConversation
    #>
    [CmdletBinding()]
    param ()
    try {
        Invoke-MetroAIApiCall -Service 'openai/conversations' -Operation 'conversation' -Method Post -ContentType "application/json" -Body @{}
    }
    catch {
        Write-Error "New-MetroAIConversation error: $_"
    }
}
