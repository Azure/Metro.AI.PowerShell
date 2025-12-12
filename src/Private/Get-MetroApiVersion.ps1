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
    # Legacy version selection removed; only the new preview API version is supported.
    return '2025-11-15-preview'
}
