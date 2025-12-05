function Get-MetroAIMessage {
    <#
    .SYNOPSIS
        Retrieves messages from a thread.
    .DESCRIPTION
        Returns the messages for the specified thread.
    .PARAMETER ThreadID
        The thread ID.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID
    )
    try {
        throw "Thread messages are not supported in the Foundry Agents preview API. Use Get-MetroAIConversation and Get-MetroAIResponse instead."
    }
    catch {
        Write-Error "Get-MetroAIMessage error: $_"
    }
}
