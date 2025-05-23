#region Helper Functions

class MetroAIContext {
    [string]$Endpoint
    [ValidateSet('Agent', 'Assistant')]
    [string]$ApiType

    [bool]$UseNewApi
    [string]$ApiVersion

    MetroAIContext([string]$endpoint, [string]$apiType, [string]$apiVersion = "") {
        # keep your original logic for simple endpoint+apiType
        $this.Endpoint = $endpoint.TrimEnd('/')
        $this.ApiType = $apiType
        $this.ApiVersion = $apiVersion

        # auto-detect new vs old based on hostname
        # new AI endpoints live under *.ai.azure.com
        $this.UseNewApi = $this.Endpoint -match '\.ai\.azure\.com'
    }

    MetroAIContext([string]$connectionString, [string]$apiType, [switch]$fromConnectionString) {
        # exactly your original split/format
        $parts = $connectionString -split ';'
        if ($parts.Count -ne 4) { throw "Invalid connection string format." }
        $this.Endpoint = ('https://{0}/agents/v1.0/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.MachineLearningServices/workspaces/{3}' -f $parts)
        $this.ApiType = $apiType
        $this.ApiVersion = ""
    }

    [string] ResolveUri(
        [string]$Service,
        [string]$Operation,
        [string]$Path = "",
        [switch]$UseOpenPrefix
    ) {
        if ($this.UseNewApi) {
            # new surface: endpoint already includes /api/projects/{…}
            $base = "$($this.Endpoint)/$Service"
            if ($Path) { $base += "/$Path" }
            $ver = if ($this.ApiVersion) { $this.ApiVersion } else { '2025-05-15-preview' }
            return "$base`?api-version=$ver"
        }

        # old-style behavior
        $prefix = ($this.ApiType -eq 'Assistant' -and $UseOpenPrefix) ? "openai/" : ""
        $baseUri = "$($this.Endpoint)/$prefix$Service"
        if ($Path) { $baseUri += "/$Path" }
        $ver = if ($this.ApiVersion) { $this.ApiVersion } else { Get-MetroApiVersion -Operation $Operation -ApiType $this.ApiType }
        return "$baseUri`?api-version=$ver"
    }
}

function Set-MetroAIContext {
    [CmdletBinding(DefaultParameterSetName = 'Endpoint')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Endpoint')]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType,

        [Parameter(Mandatory, ParameterSetName = 'ConnectionString')]
        [string]$ConnectionString,

        [string]$ApiVersion
    )

    if ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
        Write-Verbose "Setting context from connection string"
        $script:MetroContext = [MetroAIContext]::new($ConnectionString, $ApiType, $true)
    }
    else {
        Write-Verbose "Setting context for endpoint $Endpoint"
        $script:MetroContext = [MetroAIContext]::new($Endpoint, $ApiType, $ApiVersion)
    }
}



function Get-MetroAIContext {
    if ($script:MetroContext) {
        return $script:MetroContext
    }
    else {
        Write-Error "No Metro AI context set. Use Set-MetroAIContext to set it."
    }
}

function Get-MetroAuthHeader {
    <#
    .SYNOPSIS
        Returns a header hashtable with an authorization token for the specified API type,
        automatically choosing the right Azure resource URL for old vs new endpoints.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        # make sure our context is set
        if (-not $script:MetroContext) {
            throw "No Metro AI context set. Use Set-MetroAIContext first."
        }

        # decide which resource to ask a token for
        if ($script:MetroContext.UseNewApi) {
            # unified new AI surface
            $resourceUrl = "https://ai.azure.com/"
        }
        elseif ($ApiType -eq 'Agent') {
            # old Agent endpoint
            $resourceUrl = "https://ml.azure.com/"
        }
        else {
            # old Assistant endpoint
            $resourceUrl = "https://cognitiveservices.azure.com/"
        }

        # grab the token
        $token = (Get-AzAccessToken -ResourceUrl $resourceUrl -AsSecureString).Token `
        | ConvertFrom-SecureString -AsPlainText
        if (-not $token) {
            throw "Token retrieval failed for resource $resourceUrl"
        }

        # return the bare auth header;
        # x-ms-enable-preview goes in Invoke-MetroAIApiCall so it’s applied on every request uniformly
        return @{ Authorization = "Bearer $token" }
    }
    catch {
        Write-Error "Get-MetroAuthHeader error for '$ApiType': $_"
    }
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

function Invoke-MetroAIApiCall {
    <#
    .SYNOPSIS
        Generalized API caller for Metro AI endpoints.
    .DESCRIPTION
        Constructs the full API URI, obtains the authorization header, merges additional headers,
        and invokes the REST method with error handling.
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
    if (-not $script:MetroContext) {
        throw "MetroAI context not set. Use Set-MetroAIContext before invoking calls."
    }
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $script:MetroContext.ApiType
        if ($AdditionalHeaders) { $authHeader += $AdditionalHeaders }

        $uri = $script:MetroContext.ResolveUri($Service, $Operation, $Path, $UseOpenPrefix)

        Write-Verbose "Calling API at URI: $uri with method $Method"

        $invokeParams = @{
            Uri        = $uri
            Method     = $Method
            Headers    = $authHeader
            TimeoutSec = $TimeoutSeconds
        }
        if ($ContentType) { $invokeParams.ContentType = $ContentType }
        if ($Form) {
            $invokeParams.Form = $Form
        }
        elseif ($Body) {
            if ($ContentType -eq "application/json") {
                $invokeParams.Body = $Body | ConvertTo-Json -Depth 100
            }
            else {
                $invokeParams.Body = $Body
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
    .PARAMETER Purpose
        The purpose of the file upload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string]$Purpose = "assistants"
    )
    try {
        $fileItem = Get-Item -Path $FilePath -ErrorAction Stop
        $body = @{ purpose = $Purpose; file = $fileItem }
        Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Method Post -Form $body -ContentType "multipart/form-data"
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
    .PARAMETER FileId
        Optional file ID.
    .PARAMETER LocalFilePath
        Optional path to save the file.
    #>
    [CmdletBinding(DefaultParameterSetName = 'NoFileId')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'FileId')] [string]$FileId,
        [Parameter(Mandatory = $false, ParameterSetName = 'FileId')] [string]$LocalFilePath
    )
    try {
        if ($PSBoundParameters['LocalFilePath'] -and -not $PSBoundParameters['FileId']) {
            Write-Error "LocalFilePath can only be used with FileId."
            break
        }
        $files = Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Method Get
        if (-not [string]::IsNullOrWhiteSpace($FileId)) {
            $item = $files.data | Where-Object { $_.id -eq $FileId -and $_.purpose -eq "assistants_output" }
            if ($item) {
                $content = Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Path ("{0}/content" -f $FileId) -Method Get
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
    .PARAMETER FileId
        Optional specific file ID.
    #>
    [CmdletBinding()]
    param (
        [string]$FileId
    )
    try {
        $files = Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Method Get
        if ($FileId) {
            $item = $files.data | Where-Object { $_.id -eq $FileId }
            if ($item) {
                Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Path $FileId -Method Delete
                Write-Output "File $FileId deleted."
            }
            else { Write-Error "File $FileId not found." }
        }
        else {
            foreach ($file in $files.data) {
                try {
                    Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Path $file.id -Method Delete
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
    <#
        .SYNOPSIS
            Creates a new AI Foundry resource (Agent or Assistant).
        .DESCRIPTION
            This function creates a new AI agent or assistant using the specified model and instructions. It optionally reads instructions from a meta prompt file and, for Assistants, can attach file identifiers. If no resource name is provided, a default name is generated based on the current date and time.
        .PARAMETER InstructionsFile
            The file path to a text file containing a meta prompt (instructions) for the resource. When provided, the contents are read and concatenated into a single string.
        .PARAMETER Model
            The identifier of the model to be used for the Metro AI resource.
        .PARAMETER FileIds
            (Optional) An array of file identifiers to attach to the resource when the ApiType is 'Assistant'.
        .PARAMETER ResourceName
            (Optional) The desired name for the resource. If not provided, a default name is generated automatically.
        .EXAMPLE
            New-MetroAIResource -Model "gpt-4" -Endpoint "https://example.azure.com" -ApiType Assistant -MetaPromptFile "C:\path\to\prompt.txt" -FileIds @("file1", "file2")
        .NOTES
            Ensure that the Endpoint is reachable and you have the necessary permissions. The generated resource name is based on the current date and time if none is provided.
    #>
    [Alias("New-MetroAIAgent")]
    [Alias("New-MetroAIAssistant")]
    [CmdletBinding(DefaultParameterSetName = 'NoPrompt')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'MetaPromptFile')][string]$InstructionsFile = "",
        [Parameter(Mandatory = $false, ParameterSetName = 'MetaPrompt')][string]$Instructions = "",
        [Parameter(Mandatory = $true)] [string]$Model,
        [string[]]$FileIds,
        [Parameter(Mandatory = $false)] [string]$ResourceName = ""
    )
    try {
        if (-not($PSBoundParameters['Instructions'])) {
            $Instructions = if ($InstructionsFile) { (Get-Content -Path $InstructionsFile -ErrorAction Stop) -join "`n" } else { "" }
        }

        if (-not $ResourceName) { $ResourceName = (Get-Date -Format ddMMyyHHmmss) + "-agent" }
        Write-Verbose "Creating resource with name: $ResourceName"
        $body = @{
            instructions = $Instructions
            name         = $ResourceName
            tools        = @(
                @{ type = "file_search" },
                @{ type = "code_interpreter" }
            )
            model        = $Model
        }
        if ($ApiType -eq 'Assistant' -and $FileIds) { $body.file_ids = $FileIds }
        Invoke-MetroAIApiCall -Service 'assistants' -Operation 'create' -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        Write-Error "New-MetroAIResource error: $_"
    }
}

function Set-MetroAIResource {
    [Alias("Set-MetroAIAgent")]
    [Alias("Set-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, parameterSetName = 'AssistantId')][string]$AssistantId,
        [Parameter(Mandatory = $true, parameterSetName = 'Json')][string]$InputFile = "",
        [Parameter(Mandatory = $false, parameterSetName = 'AssistantId')][string]$Body = ""
    )

    try {
        if ($InputFile) {
            Write-Verbose "Getting content from file: $InputFile"
            $requestBody = Get-Content -Path $InputFile -Raw | ConvertFrom-Json -Depth 100 -NoEnumerate
            $requestAssistantId = $requestBody.id
            $requestBody = $requestBody | Select-Object -ExcludeProperty id, object, created_at
        }

        Invoke-MetroAIApiCall -Service 'assistants' -Operation 'create' -Path $requestAssistantId -Method Post -ContentType "application/json" -Body $requestBody
    }
    catch {
        Write-Error "Set-MetroAIResource error: $_"
    }
}

function Get-MetroAIResource {
    <#
        .SYNOPSIS
            Retrieves details of Metro AI resources (Agent or Assistant).
        .DESCRIPTION
            This function queries the specified Metro AI service endpoint to retrieve resource details. If an AssistantId is provided, it returns details for that specific resource; otherwise, it returns a collection of all available resources based on the ApiType.
        .PARAMETER AssistantId
            (Optional) The unique identifier of a specific assistant resource to retrieve. If not provided, the function returns all available resources.
        .EXAMPLE
            Get-MetroAIResource -AssistantId "resource-123" -Endpoint "https://example.azure.com" -ApiType Agent
        .EXAMPLE
            Get-MetroAIResource -Endpoint "https://example.azure.com" -ApiType Assistant
        .NOTES
            When an AssistantId is provided, the function returns the detailed resource object; otherwise, it returns an array of resource summaries.
    #>
    [Alias("Get-MetroAIAgent")]
    [Alias("Get-MetroAIAssistant")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string]$AssistantId
    )
    try {
        $path = $AssistantId
        $result = Invoke-MetroAIApiCall -Service 'assistants' -Operation 'get' -Path $path -Method Get
        if ($PSBoundParameters['AssistantId']) { return $result } else { return $result.data }
    }
    catch {
        Write-Error "Get-MetroAIResource error: $_"
    }
}

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

#endregion

#region Threads and Messaging

function New-MetroAIThread {
    <#
    .SYNOPSIS
        Creates a new thread.
    .DESCRIPTION
        Initiates a new thread for an agent or assistant.
    #>
    [CmdletBinding()]
    param (
    )
    try {
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Method Post -ContentType "application/json"
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
    .PARAMETER ThreadID
        The thread ID.
    #>
    [CmdletBinding()]
    param (
        [string]$ThreadID
    )
    try {
        $result = Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path $ThreadID -Method Get
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
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$Message
    )
    try {
        $body = @(@{ role = "user"; content = $Message })
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path ("{0}/messages" -f $ThreadID) -Method Post -ContentType "application/json" -Body $body
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
    .PARAMETER Async
        Run asynchronously.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [switch]$Async
    )
    try {
        $body = @{ assistant_id = $AssistantId }
        $runResponse = Invoke-MetroAIApiCall -Service 'threads' `
            -Operation 'threadStatus' -Path ("{0}/runs" -f $ThreadID) -Method Post `
            -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                $runResult = Invoke-MetroAIApiCall -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $runResponse.id) -Method Get
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $result = Invoke-MetroAIApiCall -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $ThreadID) -Method Get
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
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID,
        [Parameter(Mandatory = $true)] [string]$RunID
    )
    try {
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $ThreadID, $RunID) -Method Get
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
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ThreadID
    )
    try {
        Invoke-MetroAIApiCall -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $ThreadID) -Method Get | Select-Object -ExpandProperty data
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
    .PARAMETER Endpoint
        The base API URL.
    .PARAMETER MessageContent
        The initial message.
    .PARAMETER Async
        Run asynchronously.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$MessageContent,
        [switch]$Async
    )
    try {
        $body = @{
            assistant_id = $AssistantId;
            thread       = @{ messages = @(@{ role = "user"; content = $MessageContent }) }
        }
        $response = Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path "runs" -Method Post -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            do {
                Start-Sleep -Seconds 10
                Write-Verbose "Checking thread status..."
                $runResult = Invoke-MetroAIApiCall -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $response.thread_id, $response.id) -Method Get
                $i++
            } while ($runResult.status -ne "completed" -and $i -lt 100)
            if ($runResult.status -eq "completed") {
                $result = Invoke-MetroAIApiCall -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $response.thread_id) -Method Get
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

#endregion

# Export module members with the Metro prefix.
Export-ModuleMember -Function * -Alias *

