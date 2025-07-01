function Invoke-MetroAIMessage {
    <#
    .SYNOPSIS
        Sends a message to a thread.
    .DESCRIPTION
        Sends a message payload to the specified thread.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Message
        The message content.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$Message
    )
    try {
        $body = @(@{ role = "user"; content = $Message })
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path ("{0}/messages" -f $ThreadID) -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Invoke-MetroAIMessage error: $_"
    }
}
