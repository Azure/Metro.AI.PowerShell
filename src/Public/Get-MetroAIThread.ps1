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
        $result = Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path $ThreadID -Method Get
        if ($PSBoundParameters['ThreadID']) { return $result } else { return $result.data }
    }
    catch {
        Write-Error "Get-MetroAIThread error: $_"
    }
}
