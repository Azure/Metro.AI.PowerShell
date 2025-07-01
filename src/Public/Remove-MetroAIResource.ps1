function Remove-MetroAIResource {
    <#
        .SYNOPSIS
            Removes one or more Metro AI resources (Agent or Assistant).
        .DESCRIPTION
            This function deletes Metro AI resources from the specified endpoint. When an AssistantId is provided, it deletes that specific resource. Otherwise, it retrieves all resources for the specified ApiType and attempts to delete each one. Use caution, as this action is irreversible.
        .PARAMETER All
            (Optional) Switch parameter to delete all resources. When used, the function will delete every resource matching the specified ApiType.
        .PARAMETER AssistantId
            (Optional) The unique identifier of a specific assistant resource to delete. If provided, only that resource is deleted.
        .EXAMPLE
            Remove-MetroAIResource -Endpoint "https://example.azure.com" -ApiType Agent -AssistantId "resource-123"
        .EXAMPLE
            Remove-MetroAIResource -Endpoint "https://example.azure.com" -ApiType Assistant -All
        .NOTES
            This function permanently deletes resources. Confirm that the resources are no longer needed before executing this command.
    #>
    [Alias("Remove-MetroAIAgent")]
    [Alias("Remove-MetroAIAssistant")]
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(
            ParameterSetName = 'All',
            Mandatory = $false)]
        [switch]$All,

        [Alias('id')]
        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true)]
        [string]$AssistantId
    )
    begin {
        $idsToDelete = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $idsToDelete += $AssistantId
        }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'All') {
            $resources = Get-MetroAIResource
            $idsToDelete = $resources.id
        }
        if ($idsToDelete.Count -eq 0) {
            Write-Error "No resources to delete."
            return
        }
        foreach ($id in $idsToDelete) {
            try {
                Invoke-MetroAIApiCall -Service 'assistants' -Operation 'create' -Path $id -Method Delete

            }
            catch {
                Write-Error "Failed to delete resource with ID: $id. Error: $_"
            }
        }
    }

}
