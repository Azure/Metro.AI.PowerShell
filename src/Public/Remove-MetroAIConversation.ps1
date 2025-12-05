function Remove-MetroAIConversation {
    <#
        .SYNOPSIS
            Deletes a conversation by id.
        .EXAMPLE
            Remove-MetroAIConversation -ConversationId "abc123"
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string[]]$ConversationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromPipeline', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$InputObject
    )
    begin {
        $conversationsToDelete = [System.Collections.Generic.List[string]]::new()
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    foreach ($id in $ConversationId) {
                        if ($id) { $conversationsToDelete.Add($id) }
                    }
                }
                'FromPipeline' {
                    if ($InputObject -is [string]) {
                        $conversationsToDelete.Add($InputObject)
                    }
                    elseif ($InputObject.PSObject.Properties.Match('id')) {
                        $conversationsToDelete.Add($InputObject.id)
                    }
                    else {
                        throw "Pipeline object does not contain an 'id' property. Unable to determine conversation identifier."
                    }
                }
            }
        }
        catch {
            Write-Error "Remove-MetroAIConversation error: $_"
        }
    }
    end {
        foreach ($id in ($conversationsToDelete | Select-Object -Unique)) {
            if (-not $id) { continue }
            try {
                if ($PSCmdlet.ShouldProcess($id, "Delete conversation")) {
                    Invoke-MetroAIApiCall -Service 'openai/conversations' -Operation 'conversation' -Path $id -Method Delete | Out-Null
                }
            }
            catch {
                Write-Error "Remove-MetroAIConversation error deleting '$id': $_"
            }
        }
    }
}
