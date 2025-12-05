function Remove-MetroAIResponse {
    <#
        .SYNOPSIS
            Deletes a response by id.
        .EXAMPLE
            Remove-MetroAIResponse -ResponseId "resp123"
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string[]]$ResponseId,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromPipeline', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$InputObject
    )
    begin {
        $responsesToDelete = [System.Collections.Generic.List[string]]::new()
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    foreach ($id in $ResponseId) {
                        if ($id) { $responsesToDelete.Add($id) }
                    }
                }
                'FromPipeline' {
                    if ($InputObject -is [string]) {
                        $responsesToDelete.Add($InputObject)
                    }
                    elseif ($InputObject.PSObject.Properties.Match('id')) {
                        $responsesToDelete.Add($InputObject.id)
                    }
                    else {
                        throw "Pipeline object does not contain an 'id' property. Unable to determine response identifier."
                    }
                }
            }
        }
        catch {
            Write-Error "Remove-MetroAIResponse error: $_"
        }
    }
    end {
        foreach ($id in ($responsesToDelete | Select-Object -Unique)) {
            if (-not $id) { continue }
            try {
                if ($PSCmdlet.ShouldProcess($id, "Delete response")) {
                    Invoke-MetroAIApiCall -Service 'openai/responses' -Operation 'responses' -Path $id -Method Delete | Out-Null
                }
            }
            catch {
                Write-Error "Remove-MetroAIResponse error deleting '$id': $_"
            }
        }
    }
}
