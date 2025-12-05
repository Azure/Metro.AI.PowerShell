function Get-MetroAIConversation {
    <#
        .SYNOPSIS
            Retrieves conversations or a specific conversation.
        .EXAMPLE
            Get-MetroAIConversation
        .EXAMPLE
            Get-MetroAIConversation -ConversationId "abc123"
    #>
    [CmdletBinding(DefaultParameterSetName = "List")]
    param(
        [Parameter(ParameterSetName = "GetById", Mandatory = $true)]
        [string]$ConversationId
    )
    try {
        $path = if ($PSCmdlet.ParameterSetName -eq 'GetById') { $ConversationId } else { $null }
        $result = Invoke-MetroAIApiCall -Service 'openai/conversations' -Operation 'conversation' -Path $path -Method Get

        if ($PSCmdlet.ParameterSetName -eq 'List') {
            if ($result.PSObject.Properties.Name -contains 'value') { return $result.value }
            if ($result.PSObject.Properties.Name -contains 'data') { return $result.data }
        }
        return $result
    }
    catch {
        Write-Error "Get-MetroAIConversation error: $_"
    }
}
