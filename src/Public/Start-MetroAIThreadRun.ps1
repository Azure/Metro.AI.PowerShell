function Start-MetroAIThreadRun {
    <#
    .SYNOPSIS
        Initiates a run on a thread.
    .DESCRIPTION
        Starts a run on the specified thread and waits for completion unless Async is specified.
    .PARAMETER AssistantId
        The agent or assistant ID.
    .PARAMETER ThreadID
        The thread ID.
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
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [switch]$Async,
        [string]$McpServerLabel,
        [Parameter()][hashtable]$McpToolOverrides
    )
    try {
        throw "Thread runs are not supported in the Foundry Agents preview API. Use New-MetroAIConversation and Invoke-MetroAIConversation instead."
    }
    catch {
        Write-Error "Start-MetroAIThreadRun error: $_"
    }
}
