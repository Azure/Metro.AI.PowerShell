function New-MetroAIFunction {
    <#
    .SYNOPSIS
        Registers a custom function for an agent or assistant.
    .DESCRIPTION
        Adds a new tool definition to an existing agent or assistant.
    .PARAMETER Name
        The name of the function.
    .PARAMETER Description
        A description of the function.
    .PARAMETER RequiredPropertyName
        The required parameter name.
    .PARAMETER PropertyDescription
        A description for the required parameter.
    .PARAMETER AssistantId
        The target agent or assistant ID.
    .PARAMETER Instructions
        The instructions for the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Description,
        [Parameter(Mandatory = $true)] [string]$RequiredPropertyName,
        [Parameter(Mandatory = $true)] [string]$PropertyDescription,
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$Instructions
    )
    try {
        throw "New-MetroAIFunction is not supported with the Foundry Agents preview API. Please add tools via New/Set-MetroAIResource instead."
    }
    catch {
        Write-Error "New-MetroAIFunction error: $_"
    }
}
