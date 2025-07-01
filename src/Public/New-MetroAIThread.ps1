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
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Method Post -ContentType "application/json"
    }
    catch {
        Write-Error "New-MetroAIThread error: $_"
    }
}
