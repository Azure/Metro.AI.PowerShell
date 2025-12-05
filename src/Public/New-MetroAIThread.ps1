function New-MetroAIThread {
    <#
    .SYNOPSIS
        Creates a new thread.
    .DESCRIPTION
        Initiates a new thread for an agent or assistant.
    #>
    [CmdletBinding()]
    param (
    )
    try {
        throw "Threads are not supported in the Foundry Agents preview API. Use New-MetroAIConversation instead."
    }
    catch {
        Write-Error "New-MetroAIThread error: $_"
    }
}
