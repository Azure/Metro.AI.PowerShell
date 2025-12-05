function Add-MetroAIAgentOpenAPIDefinition {
    <#
    .SYNOPSIS
        Adds an OpenAPI definition to an agent.
    .DESCRIPTION
        Reads an OpenAPI JSON file and adds it as a tool to the specified agent.
    .PARAMETER AgentId
        The agent ID.
    .PARAMETER DefinitionFile
        The path to the OpenAPI JSON file.
    .PARAMETER Name
        Optional name for the OpenAPI definition.
    .PARAMETER Description
        Optional description.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AgentId,
        [Parameter(Mandatory = $true)] [string]$DefinitionFile,
        [string]$Name = "",
        [string]$Description = ""
    )
    try {
        throw "Add-MetroAIAgentOpenAPIDefinition is not supported with the Foundry Agents preview API. Please include OpenAPI tools via New/Set-MetroAIResource."
    }
    catch {
        Write-Error "Add-MetroAIAgentOpenAPIDefinition error: $_"
    }
}
