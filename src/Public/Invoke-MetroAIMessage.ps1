function Invoke-MetroAIMessage {
    <#
    .SYNOPSIS
        Adds a message item to a conversation.
    .DESCRIPTION
        Adds a message item to the specified conversation using the Foundry Agents preview API.
    .PARAMETER ConversationId
        The conversation ID.
    .PARAMETER Message
        The message content.
    .PARAMETER Role
        The role of the message sender. Default is 'user'.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] 
        [Alias('ThreadID')]
        [string]$ConversationId,

        [Parameter(Mandatory = $true)] 
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('user', 'assistant', 'system')]
        [string]$Role = 'user'
    )
    try {
        $body = @{
            items = @(
                @{
                    type = "message"
                    role = $Role
                    content = $Message
                }
            )
        }

        Invoke-MetroAIApiCall -Service "openai/conversations/$ConversationId/items" -Operation 'create_item' -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Invoke-MetroAIMessage error: $_"
    }
}
