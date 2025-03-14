#region Helper Functions

function Get-MetroAuthHeader {
    <#
    .SYNOPSIS
        Returns a header hashtable with an authorization token for the specified API type.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .OUTPUTS
        A hashtable suitable for use as HTTP headers.
    .EXAMPLE
        Get-MetroAuthHeader -ApiType Agent
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        $resourceUrl = ($ApiType -eq 'Agent') ? "https://ml.azure.com/" : "https://cognitiveservices.azure.com"

        $token = (Get-AzAccessToken -ResourceUrl $resourceUrl -AsSecureString).Token | ConvertFrom-SecureString -AsPlainText

        if (-not $token) { throw "Token retrieval failed." }

        return @{ Authorization = "Bearer $token" }
    }
    catch {
        Write-Error "Get-MetroAuthHeader error for '$ApiType': $_"
    }
}


function Get-MetroBaseUri {
    <#
    .SYNOPSIS
        Constructs the base URI for a given service.
    .DESCRIPTION
        Builds the full base URI by prepending "openai/" only when the API type is Assistant and the UseOpenPrefix switch is provided.
        For example, for an Assistant API:
            https://aoai-policyassistant.openai.azure.com/openai/files
        And for an Agent API:
            https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}/files
    .PARAMETER Endpoint
        The base URL of the API.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .PARAMETER Service
        The service segment (e.g. "assistants", "files", "threads").
    .PARAMETER UseOpenPrefix
        When specified and ApiType is Assistant, "openai/" is prepended.
    .OUTPUTS
        A string representing the full base URI.
    .EXAMPLE
        Get-MetroBaseUri -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant -Service files -UseOpenPrefix
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [Parameter(Mandatory=$true)]
        [string]$Service,
        [switch]$UseOpenPrefix
    )

    $prefix = ($ApiType -eq 'Assistant' -and $UseOpenPrefix) ? "openai/" : ""

    return "$Endpoint/$prefix$Service"
}


function Get-MetroApiVersion {
    <#
    .SYNOPSIS
        Returns the API version for a given operation.
    .DESCRIPTION
        Retrieves the API version string for the specified operation.
    .PARAMETER Operation
        The operation name (upload, create, get, thread, threadStatus, messages, openapi).
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .OUTPUTS
        A string with the API version.
    .EXAMPLE
        Get-MetroApiVersion -Operation create -ApiType Agent
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
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


function Get-MetroUri {
    <#
    .SYNOPSIS
        Builds the complete URI for an API call.
    .DESCRIPTION
        Constructs the final URI by calling Get-MetroBaseUri to obtain the base URI and Get-MetroApiVersion for the version.
        An optional additional path may be appended.
    .PARAMETER Endpoint
        The base URL of the API.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .PARAMETER Service
        The service segment (e.g. "assistants", "files", "threads").
    .PARAMETER Operation
        The operation name (used to get the API version).
    .PARAMETER Path
        Optional. Additional path to append to the base URI.
    .OUTPUTS
        The full URI string.
    .EXAMPLE
        Get-MetroUri -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" `
                     -ApiType Agent -Service files -Operation upload
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [Parameter(Mandatory=$true)]
        [string]$Service,
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        [string]$Path
    )
    $params = @{
        Endpoint = $Endpoint
        ApiType = $ApiType
        Service = $Service
    }
    if ($ApiType -eq 'Assistant') {
        $params.UseOpenPrefix = $true
    }

    $baseUri = Get-MetroBaseUri @params
    if ($Path) { $baseUri = "$baseUri/$Path" }
    $version = Get-MetroApiVersion -Operation $Operation -ApiType $ApiType
    $uri = '{0}?api-version={1}' -f $baseUri, $version
    Write-Verbose $uri
    return $uri
}

#endregion


#region File Upload & Output Files

function Invoke-MetroAIUploadFile {
    <#
    .SYNOPSIS
        Uploads a file to the API endpoint.
    .DESCRIPTION
        Reads a local file and uploads it via a multipart/form-data request to an agent or assistant endpoint.
    .PARAMETER FilePath
        The local path to the file.
    .PARAMETER Endpoint
        The base API URL.
        For Agent, for example:
          https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}
    .PARAMETER ApiType
        Specifies whether the call is for an Agent or an Assistant.
    .PARAMETER Purpose
        The purpose of the file upload (default is "assistants").
    .EXAMPLE
        Invoke-MetroAIUploadFile -FilePath ".\doc.txt" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [string]$Purpose = "assistants"
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $uploadUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload'
        $fileItem = Get-Item -Path $FilePath -ErrorAction Stop
        $body = @{ purpose = $Purpose; file = $fileItem }
        return Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $authHeader -ContentType "multipart/form-data" -Form $body
    }
    catch {
        Write-Error "Invoke-MetroAIUploadFile error: $_"
    }
}


function Get-MetroAIOutputFiles {
    <#
    .SYNOPSIS
        Retrieves output files for an assistant.
    .DESCRIPTION
        Downloads output files (with purpose "assistants_output") from an assistant endpoint and optionally saves them locally.
    .PARAMETER Endpoint
        The base API URL.
        For Assistant, for example:
          https://aoai-policyassistant.openai.azure.com
    .PARAMETER ApiType
        Specifies whether to target an Agent or an Assistant.
    .PARAMETER FileId
        Optional. A specific file ID.
    .PARAMETER LocalFilePath
        Optional. A path to save the file content.
    .EXAMPLE
        Get-MetroAIOutputFiles -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant -FileId "file123"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [string]$FileId,
        [string]$LocalFilePath
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload'
        $files = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
        if (![string]::IsNullOrWhiteSpace($FileId)) {
            $item = $files.data | Where-Object { $_.id -eq $FileId -and $_.purpose -eq "assistants_output" }
            if ($item) {
                $downloadUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Path ("{0}/content" -f $FileId)
                $content = Invoke-RestMethod -Uri $downloadUri -Headers $authHeader -Method Get
                if ($LocalFilePath) {
                    $content | Out-File -FilePath $LocalFilePath -Force -Verbose
                }
                else {
                    return $content
                }
            }
            else {
                Write-Error "File $FileId not found or wrong purpose."
            }
        }
        else {
            $outputFiles = $files.data | Where-Object { $_.purpose -eq "assistants_output" }
            if ($outputFiles.Count -gt 0) {
                return $outputFiles
            }
            else {
                Write-Output "No output files found."
            }
        }
    }
    catch {
        Write-Error "Get-MetroAIOutputFiles error: $_"
    }
}


function Remove-MetroAIFiles {
    <#
    .SYNOPSIS
        Deletes files from an endpoint.
    .DESCRIPTION
        Removes the specified file (or all files if FileId is not provided) from an agent or assistant endpoint.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Specifies whether to target an Agent or an Assistant.
    .PARAMETER FileId
        Optional. The specific file ID to delete.
    .EXAMPLE
        Remove-MetroAIFiles -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent -FileId "file123"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [string]$FileId
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload'
        $files = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
        if ($FileId) {
            $item = $files.data | Where-Object { $_.id -eq $FileId }
            if ($item) {
                $deleteUri = "{0}/{1}" -f $uri, $FileId
                Invoke-RestMethod -Uri $deleteUri -Headers $authHeader -Method Delete
                Write-Output "File $FileId deleted."
            }
            else {
                Write-Error "File $FileId not found."
            }
        }
        else {
            foreach ($file in $files.data) {
                $deleteUri = "{0}/{1}" -f $uri, $file.id
                try {
                    Invoke-RestMethod -Uri $deleteUri -Headers $authHeader -Method Delete
                }
                catch {
                    Write-Error "Error deleting file $($file.id): $_"
                }
            }
        }
    }
    catch {
        Write-Error "Remove-MetroAIFiles error: $_"
    }
}

#endregion


#region Resource Management

function New-MetroAIResource {
    [Alias("New-MetroAIAgent")]
    [Alias("New-MetroAIAssistant")]
    <#
    .SYNOPSIS
        Creates a new agent or assistant.
    .DESCRIPTION
        Uses an optional meta prompt file, model name, and (for assistants) file IDs to create a new agent or assistant instance.
    .PARAMETER MetaPromptFile
        Optional file path for the meta prompt.
    .PARAMETER Model
        The model to use.
    .PARAMETER Endpoint
        The base API URL.
        For Agent, for example:
          https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}
        For Assistant, for example:
          https://aoai-policyassistant.openai.azure.com
    .PARAMETER ApiType
        Agent or Assistant.
    .PARAMETER FileIds
        (For Assistant only) An array of file IDs.
    .PARAMETER ResourceName
        Optional name for the agent or assistant; if omitted, a timestamp-based name is generated.
    .EXAMPLE
        New-MetroAIResource -MetaPromptFile ".\prompt.txt" -Model "gpt-4" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [string]$MetaPromptFile = "",
        [Parameter(Mandatory=$true)]
        [string]$Model,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,
        [string[]]$FileIds,
        [Parameter(Mandatory=$false)]
        [string]$ResourceName = ""
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $metaPrompt = if ($MetaPromptFile) { (Get-Content -Path $MetaPromptFile -ErrorAction Stop) -join "`n" } else { "" }
        if (-not $ResourceName) {
            $ResourceName = (Get-Date -Format "dd-HH-mm-ss") + "-resource"
        }
        $body = @{
            instructions = $metaPrompt
            name         = $ResourceName
            tools        = @(
                @{ type = "file_search" },
                @{ type = "code_interpreter" }
            )
            model        = $Model
        }
        if ($ApiType -eq 'Assistant' -and $FileIds) {
            $body.file_ids = $FileIds
        }
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'create'
        $bodyJson = $body | ConvertTo-Json -Depth 100
        return Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $bodyJson
    }
    catch {
        Write-Error "New-MetroAIResource error: $_"
    }
}


function Get-MetroAIResource {
    [Alias("Get-MetroAIAgent")]
    [Alias("Get-MetroAIAssistant")]
    <#
    .SYNOPSIS
        Retrieves details for an agent or assistant.
    .DESCRIPTION
        Returns details about a specified agent or assistant, or all if no identifier is provided.
    .PARAMETER ResourceId
        Optional. The agent or assistant ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Get-MetroAIResource -ResourceId "res123" -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant
    #>
    [CmdletBinding()]
    param (
        [string]$ResourceId,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'get' -Path $ResourceId
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
    }
    catch {
        Write-Error "Get-MetroAIResource error: $_"
    }
}


function Remove-MetroAIResource {
    [Alias("Remove-MetroAIAgent")]
    [Alias("Remove-MetroAIAssistant")]
    <#
    .SYNOPSIS
        Deletes all agents or assistants.
    .DESCRIPTION
        Retrieves all agents or assistants from the endpoint and deletes each one.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Remove-MetroAIResource -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'create'
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $resources = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
        foreach ($res in $resources.data) {
            $deleteUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'create' -Path $res.id
            Invoke-RestMethod -Uri $deleteUri -Headers $authHeader -Method Delete
        }
    }
    catch {
        Write-Error "Remove-MetroAIResource error: $_"
    }
}

#endregion


#region Function Registration

function New-MetroAIFunction {
    <#
    .SYNOPSIS
        Registers a custom function for an agent or assistant.
    .DESCRIPTION
        Adds a new tool (custom function) definition to an existing agent or assistant.
    .PARAMETER Name
        The name of the function.
    .PARAMETER Description
        A description of the function.
    .PARAMETER RequiredPropertyName
        The required parameter name.
    .PARAMETER PropertyDescription
        A description for the required parameter.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ResourceId
        The ID of the target agent or assistant.
    .PARAMETER Instructions
        The instructions for the function.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        New-MetroAIFunction -Name "MyFunc" -Description "Does something" -RequiredPropertyName "input" -PropertyDescription "An input value" `
            -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" `
            -ResourceId "res123" -Instructions "Run this" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$RequiredPropertyName,
        [Parameter(Mandatory=$true)]
        [string]$PropertyDescription,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [string]$ResourceId,
        [Parameter(Mandatory=$true)]
        [string]$Instructions,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $resource = Get-MetroAIResource -ResourceId $ResourceId -Endpoint $Endpoint -ApiType $ApiType
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
            id    = $ResourceId
            model = $model
        } | ConvertTo-Json -Depth 100
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'get'
        return Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "New-MetroAIFunction error: $_"
    }
}

#endregion


#region Threads and Messaging

function New-MetroAIThread {
    <#
    .SYNOPSIS
        Creates a new thread.
    .DESCRIPTION
        Initiates a new thread for an agent or assistant.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        New-MetroAIThread -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" `
            -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread'
        return Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json"
    }
    catch {
        Write-Error "New-MetroAIThread error: $_"
    }
}


function Get-MetroAIThread {
    <#
    .SYNOPSIS
        Retrieves thread details.
    .DESCRIPTION
        Returns details of a specified thread for an agent or assistant.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ThreadID
        Optional. The thread ID.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Get-MetroAIThread -Endpoint "https://aoai-policyassistant.openai.azure.com" -ThreadID "thread123" -ApiType Assistant
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [string]$ThreadID,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path $ThreadID
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
    }
    catch {
        Write-Error "Get-MetroAIThread error: $_"
    }
}


function Invoke-MetroAIMessage {
    <#
    .SYNOPSIS
        Sends a message to a thread.
    .DESCRIPTION
        Uses the approved verb "Invoke" to send a message payload to the specified thread for an agent or assistant.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Message
        The message content.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Invoke-MetroAIMessage -ThreadID "thread123" -Message "Hello" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ThreadID,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $body = @(
            @{ role = "user"; content = $Message }
        ) | ConvertTo-Json -Depth 100
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path ("{0}/messages" -f $ThreadID)
        return Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Invoke-MetroAIMessage error: $_"
    }
}


function Start-MetroAIThreadRun {
    <#
    .SYNOPSIS
        Initiates a run on a thread.
    .DESCRIPTION
        Starts a run on the specified thread for an agent or assistant and waits for completion unless Async is specified.
    .PARAMETER ResourceId
        The ID of the agent or assistant.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .PARAMETER Async
        Switch to run asynchronously.
    .EXAMPLE
        Start-MetroAIThreadRun -ResourceId "res123" -ThreadID "thread123" -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceId,
        [Parameter(Mandatory=$true)]
        [string]$ThreadID,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType,
        [switch]$Async
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $body = @{ assistant_id = $ResourceId } | ConvertTo-Json -Depth 100
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs" -f $ThreadID)
        $runResponse = Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                $statusUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $runResponse.id)
                $runResult = Invoke-RestMethod -Uri $statusUri -Headers $authHeader
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $messagesUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path $ThreadID
                $result = Invoke-RestMethod -Uri $messagesUri -Headers $authHeader
                return $result.data | ForEach-Object { $_.content.text }
            }
            else {
                Write-Error "Run did not complete in time."
            }
        }
        else {
            Write-Output "Run started asynchronously. Use Get-MetroAIThreadStatus to check."
        }
        return $runResponse
    }
    catch {
        Write-Error "Start-MetroAIThreadRun error: $_"
    }
}


function Get-MetroAIThreadStatus {
    <#
    .SYNOPSIS
        Retrieves the status of a thread run.
    .DESCRIPTION
        Returns the status details of a run for the specified thread in an agent or assistant.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER RunID
        The run ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Get-MetroAIThreadStatus -ThreadID "thread123" -RunID "run456" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ThreadID,
        [Parameter(Mandatory=$true)]
        [string]$RunID,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $RunID)
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
    }
    catch {
        Write-Error "Get-MetroAIThreadStatus error: $_"
    }
}


function Get-MetroAIMessages {
    <#
    .SYNOPSIS
        Retrieves messages from a thread.
    .DESCRIPTION
        Returns the messages from the specified thread for an agent or assistant.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .EXAMPLE
        Get-MetroAIMessages -ThreadID "thread123" -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ThreadID,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType
    )
    try {
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path $ThreadID
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        return Invoke-RestMethod -Uri $uri -Headers $authHeader
    }
    catch {
        Write-Error "Get-MetroAIMessages error: $_"
    }
}


function Start-MetroAIThreadWithMessages {
    <#
    .SYNOPSIS
        Creates a new thread with an initial message.
    .DESCRIPTION
        Initiates a new thread for an agent or assistant and sends an initial message.
    .PARAMETER ResourceId
        The ID of the agent or assistant.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER MessageContent
        The initial message.
    .PARAMETER ApiType
        Agent or Assistant.
    .PARAMETER Async
        Optional. Run asynchronously.
    .EXAMPLE
        Start-MetroAIThreadWithMessages -ResourceId "res123" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -MessageContent "Hello" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceId,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [string]$MessageContent,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent','Assistant')]
        [string]$ApiType,
        [switch]$Async
    )
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        $body = @{
            assistant_id = $ResourceId;
            thread      = @{ messages = @(@{ role = "user"; content = $MessageContent }) }
        } | ConvertTo-Json -Depth 100
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path "runs"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                $statusUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $response.thread_id, $response.id)
                $runResult = Invoke-RestMethod -Uri $statusUri -Headers $authHeader
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $messagesUri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path $response.thread_id
                $result = Invoke-RestMethod -Uri $messagesUri -Headers $authHeader
                return $result.data | ForEach-Object { $_.content.text }
            }
            else {
                Write-Error "Thread run did not complete in time."
            }
        }
        else {
            Write-Output "Run started asynchronously. Use Get-MetroAIThreadStatus to check."
        }
        return @{ ThreadID = $response.thread_id; RunID = $response.id }
    }
    catch {
        Write-Error "Start-MetroAIThreadWithMessages error: $_"
    }
}

#endregion


#region OpenAPI Definition (Agent Only)

function Add-MetroAIAgentOpenAPIDefinition {
    <#
    .SYNOPSIS
        Adds an OpenAPI definition to an agent.
    .DESCRIPTION
        Reads an OpenAPI JSON file and adds it as a tool to the specified agent.
        This function only supports the Agent API type.
    .PARAMETER AgentId
        The agent ID.
    .PARAMETER Endpoint
        The base API URL.
        For Agent, for example:
            https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}
    .PARAMETER DefinitionFile
        The path to the OpenAPI JSON file.
    .PARAMETER Name
        Optional name for the OpenAPI definition.
    .PARAMETER Description
        Optional description for the OpenAPI definition.
    .PARAMETER ApiType
        Must be Agent.
    .EXAMPLE
        Add-MetroAIAgentOpenAPIDefinition -AgentId "agent123" -Endpoint "https://swedencentral.api.azureml.ms/agents/v1.0/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}" -DefinitionFile ".\openapi.json" -ApiType Agent
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$AgentId,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [string]$DefinitionFile,
        [string]$Name = "",
        [string]$Description = "",
        [Parameter(Mandatory=$true)]
        [ValidateSet('Agent')]
        [string]$ApiType
    )
    try {
        if ($ApiType -ne 'Agent') { throw "Only Agent API type is supported." }
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
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
                            security_scheme = @{
                                audience = "https://cognitiveservices.azure.com/"
                            }
                        }
                        spec = $openAPISpec
                    }
                }
            )
        } | ConvertTo-Json -Depth 100
        $uri = Get-MetroUri -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'openapi' -Path $AgentId
        return Invoke-RestMethod -Uri $uri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Add-MetroAIAgentOpenAPIDefinition error: $_"
    }
}

#endregion


# Export module members with the Metro prefix.
Export-ModuleMember -Function * -Alias *
