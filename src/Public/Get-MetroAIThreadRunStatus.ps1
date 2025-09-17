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
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $RunID) -Method Get
    }
    catch {
        Write-Error "Get-MetroAIThreadRunStatus error: $_"
    }
}
