function Get-MetroAIThread {
    <#
    .SYNOPSIS
        Retrieves thread details.
    .DESCRIPTION
        Returns details of a specified thread.
    .PARAMETER ThreadID
        The thread ID.
    #>
    [CmdletBinding()]
    param (
        [string]$ThreadID
    )
    try {
        throw "Threads are not supported in the Foundry Agents preview API. Use Get-MetroAIConversation instead."
    }
    catch {
        Write-Error "Get-MetroAIThread error: $_"
    }
}
