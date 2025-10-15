function Remove-MetroAIThread {
    <#
    .SYNOPSIS
        Removes one or more Metro AI threads.
    .DESCRIPTION
        Deletes threads from the current Metro AI project. Supports pipeline input from Get-MetroAIThread
        to make bulk deletion scenarios simple (e.g. Get-MetroAIThread | Remove-MetroAIThread).
    .PARAMETER ThreadId
        One or more thread identifiers to remove.
    .PARAMETER InputObject
        Pipeline input that contains an id (or thread_id) property identifying the thread to remove.
    .EXAMPLE
        Remove-MetroAIThread -ThreadId "thread_abc123"
    .EXAMPLE
        Get-MetroAIThread | Remove-MetroAIThread
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string[]]$ThreadId,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromPipeline', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$InputObject
    )

    begin {
        $threadsToRemove = [System.Collections.Generic.List[string]]::new()
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                foreach ($id in $ThreadId) {
                    if ($id) {
                        $threadsToRemove.Add($id)
                    }
                }
            }
            'FromPipeline' {
                if ($InputObject -is [string]) {
                    $threadsToRemove.Add($InputObject)
                }
                elseif ($InputObject.PSObject.Properties.Match('id')) {
                    $threadsToRemove.Add($InputObject.id)
                }
                elseif ($InputObject.PSObject.Properties.Match('thread_id')) {
                    $threadsToRemove.Add($InputObject.thread_id)
                }
                else {
                    throw "Input object does not contain an 'id' or 'thread_id' property. Unable to determine thread identifier."
                }
            }
        }
    }

    end {
        foreach ($id in ($threadsToRemove | Select-Object -Unique)) {
            if (-not $id) { continue }

            if ($PSCmdlet.ShouldProcess("Thread '$id'", "Remove")) {
                try {
                    Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path $id -Method Delete | Out-Null
                    Write-Verbose "Removed thread '$id'"
                }
                catch {
                    Write-Error "Failed to remove thread '$id': $_"
                }
            }
        }
    }
}
