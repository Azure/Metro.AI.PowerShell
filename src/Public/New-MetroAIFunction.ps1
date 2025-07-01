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
        $resource = Get-MetroAIResource -AssistantId $AssistantId -Endpoint $Endpoint -ApiType $ApiType
        $model = $resource.model
        $reqProps = @{
            $RequiredPropertyName = @{
                type        = "string"
                description = $PropertyDescription
            }
        }
        $body = @{
            instructions = $Instructions
            tools        = @(
                @{
                    type     = "function"
                    function = @{
                        name        = $Name
                        description = $Description
                        parameters  = @{
                            type       = "object"
                            properties = $reqProps
                            required   = @($RequiredPropertyName)
                        }
                    }
                }
            )
            id           = $AssistantId
            model        = $model
        }
        Invoke-MetroAIApiCall -Service 'assistants' -Operation 'get' -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "New-MetroAIFunction error: $_"
    }
}
