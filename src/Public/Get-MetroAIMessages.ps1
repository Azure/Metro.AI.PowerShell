function Get-MetroAIMessages {
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
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $ThreadID) -Method Get | Select-Object -ExpandProperty data
    }
    catch {
        Write-Error "Get-MetroAIMessages error: $_"
    }
}
