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
        if ($ApiType -ne 'Agent') { throw "Only Agent API type is supported." }
        $openAPISpec = Get-Content -Path $DefinitionFile -Raw | ConvertFrom-Json
        $body = @{
            tools = @(
                @{
                    type    = "openapi"
                    openapi = @{
                        name        = $Name
                        description = $Description
                        auth        = @{
                            type            = "managed_identity"
                            security_scheme = @{ audience = "https://cognitiveservices.azure.com/" }
                        }
                        spec        = $openAPISpec
                    }
                }
            )
        }
        Invoke-MetroAIApiCall -Service 'assistants' -Operation 'openapi' -Path $AgentId -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Add-MetroAIAgentOpenAPIDefinition error: $_"
    }
}
