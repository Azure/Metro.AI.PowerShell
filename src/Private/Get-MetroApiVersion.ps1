function Get-MetroApiVersion {
    <#
    .SYNOPSIS
        Returns the API version for a given operation.
    .PARAMETER Operation
        The operation name.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$Operation,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    switch ($Operation) {
        'upload' { return '2024-05-01-preview' }
        'create' { return '2024-07-01-preview' }
        'get' { return '2024-02-15-preview' }
        'thread' { return '2024-03-01-preview' }
        'threadStatus' { return '2024-05-01-preview' }
        'messages' { return '2024-05-01-preview' }
        'openapi' { return '2024-12-01-preview' }
        default { return '2024-05-01-preview' }
    }
}
