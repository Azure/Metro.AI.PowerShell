function Get-MetroAIThreadRunStatus {
    <#
    .SYNOPSIS
        Retrieves the status of a thread run.
    .DESCRIPTION
        Returns status details of a thread run.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER RunID
        The run ID.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$RunID
    )
    try {
        throw "Thread runs are not supported in the Foundry Agents preview API. Use Get-MetroAIConversation and Get-MetroAIResponse instead."
    }
    catch {
        Write-Error "Get-MetroAIThreadRunStatus error: $_"
    }
}
