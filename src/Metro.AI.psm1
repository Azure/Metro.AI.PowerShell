#region Helper Functions

function Get-MetroAuthHeader {
    <#
    .SYNOPSIS
        Returns a header hashtable with an authorization token for the specified API type.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .OUTPUTS
        A hashtable suitable for use as HTTP headers.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        $resourceUrl = if ($ApiType -eq 'Agent') { "https://ml.azure.com/" } else { "https://cognitiveservices.azure.com" }
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
    .PARAMETER Endpoint
        The base URL of the API.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .PARAMETER Service
        The service segment (e.g. "assistants", "files", "threads").
    .PARAMETER UseOpenPrefix
        When specified and ApiType is Assistant, "openai/" is prepended.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [Parameter(Mandatory = $true)] [string]$Service,
        [switch]$UseOpenPrefix
    )
    $prefix = ($ApiType -eq 'Assistant' -and $UseOpenPrefix) ? "openai/" : ""
    return "$Endpoint/$prefix$Service"
}

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

function Get-MetroUri {
    <#
    .SYNOPSIS
        Builds the complete URI for an API call.
    .DESCRIPTION
        Constructs the final URI by calling Get-MetroBaseUri and appending the API version.
    .PARAMETER Endpoint
        The base URL of the API.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .PARAMETER Service
        The service segment.
    .PARAMETER Operation
        The operation name.
    .PARAMETER Path
        Optional additional path.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [Parameter(Mandatory = $true)] [string]$Service,
        [Parameter(Mandatory = $true)] [string]$Operation,
        [string]$Path
    )
    $params = @{
        Endpoint = $Endpoint
        ApiType  = $ApiType
        Service  = $Service
    }
    if ($ApiType -eq 'Assistant') { $params.UseOpenPrefix = $true }
    $baseUri = Get-MetroBaseUri @params
    if ($Path) { $baseUri = "$baseUri/$Path" }
    $version = Get-MetroApiVersion -Operation $Operation -ApiType $ApiType
    $uri = "{0}?api-version={1}" -f $baseUri, $version
    Write-Verbose $uri
    return $uri
}

function Invoke-MetroAIApiCall {
    <#
    .SYNOPSIS
        Generalized API caller for Metro AI endpoints.
    .DESCRIPTION
        Constructs the full API URI, obtains the authorization header, merges additional headers,
        and invokes the REST method with error handling.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        The API type: Agent or Assistant.
    .PARAMETER Service
        The service segment.
    .PARAMETER Operation
        The operation name used to determine the API version.
    .PARAMETER Path
        Optional additional path appended to the URI.
    .PARAMETER Method
        The HTTP method (e.g. Get, Post, Delete). Defaults to "Get".
    .PARAMETER Body
        Optional body content for POST/PUT requests.
    .PARAMETER ContentType
        Optional content type (e.g. "application/json").
    .PARAMETER AdditionalHeaders
        Optional extra headers to merge with the authorization header.
    .PARAMETER TimeoutSeconds
        Optional REST call timeout (default 100 seconds).
    .PARAMETER UseOpenPrefix
        Switch to use the "openai/" prefix for Assistant API calls.
    .PARAMETER Form
        Optional parameter for multipart/form-data form data.
    .EXAMPLE
        Invoke-MetroAIApiCall -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant `
            -Service 'threads' -Operation 'thread' -Method Post -ContentType "application/json" `
            -Body @{ some = "data" } -UseOpenPrefix
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [Parameter(Mandatory = $true)] [string]$Service,
        [Parameter(Mandatory = $true)] [string]$Operation,
        [Parameter(Mandatory = $false)] [string]$Path,
        [Parameter(Mandatory = $false)] [string]$Method = "Get",
        [Parameter(Mandatory = $false)] [object]$Body,
        [Parameter(Mandatory = $false)] [string]$ContentType,
        [Parameter(Mandatory = $false)] [hashtable]$AdditionalHeaders,
        [Parameter(Mandatory = $false)] [int]$TimeoutSeconds = 100,
        [Parameter(Mandatory = $false)] [switch]$UseOpenPrefix,
        [Parameter(Mandatory = $false)] [object]$Form
    )
    try {
        # Get authorization header and merge additional headers if provided.
        $authHeader = Get-MetroAuthHeader -ApiType $ApiType
        if ($AdditionalHeaders) { $authHeader = $authHeader + $AdditionalHeaders }

        # Build base URI.
        $params = @{
            Endpoint = $Endpoint
            ApiType  = $ApiType
            Service  = $Service
        }
        if ($ApiType -eq 'Assistant' -and $UseOpenPrefix) { $params.Add("UseOpenPrefix", $true) }
        $baseUri = Get-MetroBaseUri @params
        if ($Path) { $baseUri = "$baseUri/$Path" }
        $version = Get-MetroApiVersion -Operation $Operation -ApiType $ApiType
        $uri = "{0}?api-version={1}" -f $baseUri, $version

        Write-Verbose "Calling API at URI: $uri with method $Method"

        # Build parameters for Invoke-RestMethod.
        $invokeParams = @{
            Uri        = $uri
            Method     = $Method
            Headers    = $authHeader
            TimeoutSec = $TimeoutSeconds
        }
        if ($ContentType) { $invokeParams.Add("ContentType", $ContentType) }
        if ($Form) {
            $invokeParams.Add("Form", $Form)
        }
        elseif ($Body) {
            if ($ContentType -and $ContentType -eq "application/json") {
                # Option A: Use a variable
                $jsonBody = $Body | ConvertTo-Json -Depth 100
                $invokeParams.Add("Body", $jsonBody)
            }
            else {
                $invokeParams.Add("Body", $Body)
            }
        }
        return Invoke-RestMethod @invokeParams
    }
    catch {
        Write-Error "Invoke-MetroAIApiCall error: $_"
    }
}

#endregion

#region File Upload & Output Files

function Invoke-MetroAIUploadFile {
    <#
    .SYNOPSIS
        Uploads a file to the API endpoint.
    .DESCRIPTION
        Reads a local file and uploads it via a multipart/form-data request.
    .PARAMETER FilePath
        The local path to the file.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Specifies whether the call is for an Agent or an Assistant.
    .PARAMETER Purpose
        The purpose of the file upload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [string]$Purpose = "assistants"
    )
    try {
        $fileItem = Get-Item -Path $FilePath -ErrorAction Stop
        $body = @{ purpose = $Purpose; file = $fileItem }
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Method Post -Form $body -ContentType "multipart/form-data"
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
        Downloads output files (with purpose "assistants_output") from an assistant endpoint.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Specifies whether to target an Agent or an Assistant.
    .PARAMETER FileId
        Optional file ID.
    .PARAMETER LocalFilePath
        Optional path to save the file.
    #>
    [CmdletBinding(DefaultParameterSetName = 'NoFileId')]
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [Parameter(Mandatory = $false, ParameterSetName = 'FileId')] [string]$FileId,
        [Parameter(Mandatory = $false, ParameterSetName = 'FileId')] [string]$LocalFilePath
    )
    try {
        if ($PSBoundParameters['LocalFilePath'] -and -not $PSBoundParameters['FileId']) {
            Write-Error "LocalFilePath can only be used with FileId."
            break
        }
        $files = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Method Get
        if (-not [string]::IsNullOrWhiteSpace($FileId)) {
            $item = $files.data | Where-Object { $_.id -eq $FileId -and $_.purpose -eq "assistants_output" }
            if ($item) {
                $content = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Path ("{0}/content" -f $FileId) -Method Get
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
            if ($outputFiles.Count -gt 0) { return $outputFiles }
            else { Write-Output "No output files found." }
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
        Removes the specified file (or all files if FileId is not provided).
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Specifies whether to target an Agent or an Assistant.
    .PARAMETER FileId
        Optional specific file ID.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [string]$FileId
    )
    try {
        $files = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Method Get
        if ($FileId) {
            $item = $files.data | Where-Object { $_.id -eq $FileId }
            if ($item) {
                Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Path $FileId -Method Delete
                Write-Output "File $FileId deleted."
            }
            else { Write-Error "File $FileId not found." }
        }
        else {
            foreach ($file in $files.data) {
                try {
                    Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'files' -Operation 'upload' -Path $file.id -Method Delete
                }
                catch { Write-Error "Error deleting file $($file.id): $_" }
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
    [CmdletBinding()]
    param (
        [string]$MetaPromptFile = "",
        [Parameter(Mandatory = $true)] [string]$Model,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [string[]]$FileIds,
        [Parameter(Mandatory = $false)] [string]$ResourceName = ""
    )
    try {
        $metaPrompt = if ($MetaPromptFile) { (Get-Content -Path $MetaPromptFile -ErrorAction Stop) -join "`n" } else { "" }
        if (-not $ResourceName) { $ResourceName = (Get-Date -Format "dd-HH-mm-ss") + "-resource" }
        $body = @{
            instructions = $metaPrompt
            name         = $ResourceName
            tools        = @(
                @{ type = "file_search" },
                @{ type = "code_interpreter" }
            )
            model        = $Model
        }
        if ($ApiType -eq 'Assistant' -and $FileIds) { $body.file_ids = $FileIds }
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'create' -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "New-MetroAIResource error: $_"
    }
}

function Get-MetroAIResource {
    [Alias("Get-MetroAIAgent")]
    [Alias("Get-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        $path = $AssistantId
        $result = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'get' -Path $path -Method Get
        if ($PSBoundParameters['AssistantId']) { return $result } else { return $result.data }
    }
    catch {
        Write-Error "Get-MetroAIResource error: $_"
    }
}

function Remove-MetroAIResource {
    [Alias("Remove-MetroAIAgent")]
    [Alias("Remove-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [Parameter(Mandatory = $false, ParameterSetName = 'All')] [switch]$All,
        [Parameter(Mandatory = $false, ParameterSetName = 'SingleAssistant')] [string]$AssistantId
    )
    try {
        if ($PSBoundParameters['AssistantId']) {
            $resources = Get-MetroAIResource -AssistantId $AssistantId -Endpoint $Endpoint -ApiType $ApiType
        }
        else {
            $resources = Get-MetroAIResource -Endpoint $Endpoint -ApiType $ApiType
        }
        foreach ($res in $resources) {
            Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'create' -Path $res.id -Method Delete
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
        Adds a new tool definition to an existing agent or assistant.
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
    .PARAMETER AssistantId
        The target agent or assistant ID.
    .PARAMETER Instructions
        The instructions for the function.
    .PARAMETER ApiType
        Agent or Assistant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Description,
        [Parameter(Mandatory = $true)] [string]$RequiredPropertyName,
        [Parameter(Mandatory = $true)] [string]$PropertyDescription,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$Instructions,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
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
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'get' -Method Post -ContentType "application/json" -Body $body
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
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Method Post -ContentType "application/json"
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
        Returns details of a specified thread.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER ApiType
        Agent or Assistant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [string]$ThreadID,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        $result = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path $ThreadID -Method Get
        if ($PSBoundParameters['ThreadID']) { return $result } else { return $result.data }
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
        Sends a message payload to the specified thread.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Message
        The message content.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$Message,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        $body = @(@{ role = "user"; content = $Message })
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path ("{0}/messages" -f $ThreadID) -Method Post -ContentType "application/json" -Body $body
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
        Starts a run on the specified thread and waits for completion unless Async is specified.
    .PARAMETER AssistantId
        The agent or assistant ID.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    .PARAMETER Async
        Run asynchronously.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [switch]$Async
    )
    try {
        $body = @{ assistant_id = $AssistantId }
        $runResponse = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' `
            -Operation 'threadStatus' -Path ("{0}/runs" -f $ThreadID) -Method Post `
            -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                $runResult = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $runResponse.id) -Method Get
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $result = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $ThreadID) -Method Get
                return $result.data | ForEach-Object { $_.content.text }
            }
            else { Write-Error "Run did not complete in time." }
        }
        else { Write-Output "Run started asynchronously. Use Get-MetroAIThreadStatus to check." }
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
        Returns status details of a run.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER RunID
        The run ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$RunID,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $RunID) -Method Get
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
        Returns the messages for the specified thread.
    .PARAMETER ThreadID
        The thread ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER ApiType
        Agent or Assistant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType
    )
    try {
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $ThreadID) -Method Get | Select-Object -ExpandProperty data
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
        Initiates a thread and sends an initial message.
    .PARAMETER AssistantId
        The agent or assistant ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER MessageContent
        The initial message.
    .PARAMETER ApiType
        Agent or Assistant.
    .PARAMETER Async
        Run asynchronously.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [string]$MessageContent,
        [Parameter(Mandatory = $true)] [ValidateSet('Agent', 'Assistant')] [string]$ApiType,
        [switch]$Async
    )
    try {
        $body = @{
            assistant_id = $AssistantId;
            thread       = @{ messages = @(@{ role = "user"; content = $MessageContent }) }
        }
        $response = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'thread' -Path "runs" -Method Post -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                $runResult = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $response.thread_id, $response.id) -Method Get
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $result = Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $response.thread_id) -Method Get
                return $result.data | ForEach-Object { $_.content.text }
            }
            else { Write-Error "Thread run did not complete in time." }
        }
        else { Write-Output "Run started asynchronously. Use Get-MetroAIThreadStatus to check." }
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
    .PARAMETER AgentId
        The agent ID.
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER DefinitionFile
        The path to the OpenAPI JSON file.
    .PARAMETER Name
        Optional name for the OpenAPI definition.
    .PARAMETER Description
        Optional description.
    .PARAMETER ApiType
        Must be Agent.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AgentId,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [string]$DefinitionFile,
        [string]$Name = "",
        [string]$Description = "",
        [Parameter(Mandatory = $true)] [ValidateSet('Agent')] [string]$ApiType
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
        Invoke-MetroAIApiCall -Endpoint $Endpoint -ApiType $ApiType -Service 'assistants' -Operation 'openapi' -Path $AgentId -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "Add-MetroAIAgentOpenAPIDefinition error: $_"
    }
}

#endregion

# Export module members with the Metro prefix.
Export-ModuleMember -Function * -Alias *

