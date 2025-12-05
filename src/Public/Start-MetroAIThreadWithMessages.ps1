function Start-MetroAIThreadWithMessages {
    <#
    .SYNOPSIS
        Creates a new thread with an initial message.
    .DESCRIPTION
        Initiates a thread and sends an initial message.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER MessageContent
        The initial message.
    .PARAMETER Async
        Run asynchronously.
    .PARAMETER McpServerLabel
        Optional MCP server label to use when invoking the run. If omitted, the single configured server is used.
    .PARAMETER McpToolOverrides
        Advanced override for MCP tool resources, allowing custom headers or approval settings per run.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$MessageContent,
        [switch]$Async,
        [string]$McpServerLabel,
        [Parameter()][hashtable]$McpToolOverrides
    )
    try {
        throw "Threads are not supported in the Foundry Agents preview API. Use New-MetroAIConversation and Invoke-MetroAIConversation instead."
    }
    catch {
        Write-Error "Start-MetroAIThreadWithMessages error: $_"
    }
}
