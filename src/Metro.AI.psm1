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
            $ver = if ($this.ApiVersion) { $this.ApiVersion } else { 'v1' }
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

        [string]$ApiVersion,

        [switch]$SkipValidation
    )

    if ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
        Write-Verbose "Setting context from connection string"
        $script:MetroContext = [MetroAIContext]::new($ConnectionString, $ApiType, $true)
    }
    else {
        Write-Verbose "Setting context for endpoint $Endpoint"
        $script:MetroContext = [MetroAIContext]::new($Endpoint, $ApiType, $ApiVersion)
    }

    # Validate the context by attempting to retrieve resources
    if (-not $SkipValidation) {
        Write-Verbose "Validating context by attempting to retrieve resources"
        try {
            $null = Get-MetroAIResource -ErrorAction Stop
            Write-Verbose "Context validation successful"
        }
        catch {
            # Clear the invalid context
            $script:MetroContext = $null
            throw "Failed to validate Metro AI context. Please check your endpoint, connection string, and API type. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Information "Metro AI context set for $ApiType API (validation skipped)" -InformationAction Continue
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

function Remove-MetroAIAutoGeneratedProperties {
    <#
    .SYNOPSIS
        Removes auto-generated properties from Metro AI resource objects that shouldn't be included in POST/PUT requests.
    .DESCRIPTION
        Cleans up resource objects by removing system-generated properties and auto-generated OpenAPI functions
        that are returned by GET requests but should not be included when creating or updating resources.
    .PARAMETER InputObject
        The resource object to clean up.
    .EXAMPLE
        $cleanedResource = Remove-MetroAIAutoGeneratedProperties -InputObject $resourceFromGet
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    process {
        Write-Verbose "Cleaning up auto-generated properties from resource object"

        # Remove system-generated properties that shouldn't be included in creation/updates
        $cleanedObject = $InputObject | Select-Object -ExcludeProperty id, object, created_at

        # Clean up OpenAPI tools by removing auto-generated functions property
        if ($cleanedObject.tools) {
            $toolsProcessed = 0
            foreach ($tool in $cleanedObject.tools) {
                if ($tool.type -eq 'openapi' -and $tool.openapi -and $tool.openapi.functions) {
                    $tool.openapi.PSObject.Properties.Remove('functions')
                    $toolsProcessed++
                    Write-Verbose "Removed auto-generated functions property from OpenAPI tool"
                }
            }
            if ($toolsProcessed -gt 0) {
                Write-Verbose "Processed $toolsProcessed OpenAPI tools and removed auto-generated functions"
            }
        }

        return $cleanedObject
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
        Creates a new Metro AI agent or assistant resource with comprehensive tool support.
    .DESCRIPTION
        Creates an Azure AI agent or assistant with various tools including connected agents, code interpreter,
        file search, Azure AI Search, custom functions, and OpenAPI integrations.
        Follows Azure best practices for parameter validation, error handling, and resource management.
        Note: Bing grounding must be added after creation using Set-MetroAIResource.
        Can create from JSON file, pipeline input object (for copying), or specify individual parameters.
    .PARAMETER InputObject
        Pipeline input object from Get-MetroAIResource. When used, creates a copy of the existing resource with a new name.
    .PARAMETER InputFile
        Path to a JSON file containing the complete resource definition to create.
    .PARAMETER Model
        The model identifier (e.g., 'gpt-4', 'gpt-4-turbo', 'gpt-35-turbo').
    .PARAMETER Name
        The name of the agent/assistant resource. Must be unique within the workspace.
    .PARAMETER Description
        Optional description for the resource (max 512 characters).
    .PARAMETER Instructions
        System instructions that guide the agent's behavior (max 256,000 characters).
    .PARAMETER Metadata
        Optional metadata as key-value pairs (max 16 pairs, keys/values max 64 chars each).
    .PARAMETER ResponseFormat
        Response format specification. Use 'text' or structured format definitions.
    .PARAMETER Temperature
        Sampling temperature between 0.0 (deterministic) and 2.0 (most random). Default is 1.0.
    .PARAMETER TopP
        Nucleus sampling parameter between 0.0 and 1.0. Alternative to temperature.
    .PARAMETER EnableConnectedAgent
        Enable a single connected agent tool.
    .PARAMETER ConnectedAgentId
        ID of the connected agent. Required when EnableConnectedAgent is used.
    .PARAMETER ConnectedAgentName
        Display name for the connected agent. Required when EnableConnectedAgent is used.
    .PARAMETER ConnectedAgentDescription
        Description of the connected agent's capabilities. Required when EnableConnectedAgent is used.
    .PARAMETER ConnectedAgentsDefinition
        Array of connected agent definitions. Each must have 'id', 'name', and 'description' properties.
    .PARAMETER EnableCodeInterpreter
        Enable Python code execution capabilities.
    .PARAMETER CodeInterpreterFileIds
        Array of file IDs to make available to the code interpreter.
    .PARAMETER EnableFileSearch
        Enable file search capabilities across vector stores.
    .PARAMETER FileSearchVectorStoreIds
        Array of vector store IDs for file search operations.
    .PARAMETER EnableAzureAiSearch
        Enable Azure AI Search integration.
    .PARAMETER AzureAiSearchIndexes
        Array of Azure AI Search index configurations.
    .PARAMETER EnableFunctionTool
        Enable custom function calling.
    .PARAMETER FunctionName
        Name of the custom function.
    .PARAMETER FunctionDescription
        Description of what the function does.
    .PARAMETER FunctionParameters
        JSON Schema defining the function's parameters.
    .PARAMETER EnableOpenApi
        Enable OpenAPI/REST API integration.
    .PARAMETER OpenApiDefinitionFile
        Path to the OpenAPI specification file (JSON format only).
    .PARAMETER OpenApiName
        Friendly name for the OpenAPI integration.
    .PARAMETER OpenApiDescription
        Description of the OpenAPI service.
    .PARAMETER OpenApiAuthType
        Authentication method: 'Anonymous', 'Connection', or 'ManagedIdentity'.
    .PARAMETER OpenApiConnectionId
        Connection ID for API authentication when using 'Connection' auth type.
    .PARAMETER OpenApiManagedAudience
        Target audience URI when using 'ManagedIdentity' auth type.
    .EXAMPLE
        New-MetroAIResource -Model 'gpt-4' -Name 'MyAssistant' -Description 'General purpose assistant'
    .EXAMPLE
        New-MetroAIResource -InputFile './existing-assistant.json'
    .EXAMPLE
        # Copy an existing agent with a new name
        $Agent = Get-MetroAIAgent -AssistantId 'asst-123'
        $Agent | New-MetroAIAgent -Name 'CopiedAgent'
    .EXAMPLE
        New-MetroAIResource -Model 'gpt-4' -Name 'CodeHelper' -EnableCodeInterpreter -CodeInterpreterFileIds @('file-123')
    .EXAMPLE
        # Create assistant, then add Bing grounding
        $assistant = New-MetroAIResource -Model 'gpt-4' -Name 'SearchBot'
        Set-MetroAIResource -AssistantId $assistant.id -EnableBingGrounding -BingConnectionId 'bing-search-connection'
    .EXAMPLE
        # Multi-tool agent with various capabilities
        New-MetroAIResource -Model 'gpt-4' -Name 'MultiToolAgent' `
            -EnableCodeInterpreter -CodeInterpreterFileIds @('file-123') `
            -EnableAzureAiSearch -AzureAiSearchIndexes @(@{ index_connection_id='search-conn'; index_name='docs'; query_type='semantic'; top_k=5 })
    .NOTES
        Requires Set-MetroAIContext to be called first. Follow Azure AI responsible AI guidelines.
        To add Bing grounding, use Set-MetroAIResource with -EnableBingGrounding after creation.
        When using InputObject from pipeline, system-generated properties are automatically excluded.
    #>
    [Alias("New-MetroAIAgent")]
    [Alias("New-MetroAIAssistant")]
    [CmdletBinding(DefaultParameterSetName = 'Parameters', SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'InputObject', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Json')]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) { throw "Input file not found: $_" }
                $extension = [System.IO.Path]::GetExtension($_).ToLower()
                if ($extension -ne '.json') { throw "Input file must be JSON format (.json)" }
                return $true
            })]
        [string]$InputFile,

        [Parameter(Mandatory, ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 256)]
        [string]$Model,

        [Parameter(Mandatory, ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 256)]
        [Alias('ResourceName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(0, 512)]
        [string]$Description,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(0, 256000)]
        [string]$Instructions,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateScript({
                if ($_.Count -gt 16) { throw "Maximum 16 metadata entries allowed" }
                foreach ($key in $_.Keys) {
                    if ($key.Length -gt 64) { throw "Metadata key '$key' exceeds 64 character limit" }
                    if ($_[$key].ToString().Length -gt 512) { throw "Metadata value for '$key' exceeds 512 character limit" }
                }
                return $true
            })]
        [hashtable]$Metadata,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [string]$ResponseFormat,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateRange(0.0, 2.0)]
        [double]$Temperature,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateRange(0.0, 1.0)]
        [double]$TopP,

        # Connected Agent Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableConnectedAgent,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectedAgentId,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 256)]
        [string]$ConnectedAgentName,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 512)]
        [string]$ConnectedAgentDescription,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateScript({
                foreach ($agent in $_) {
                    if (-not ($agent.id -and $agent.name -and $agent.description)) {
                        throw "Each ConnectedAgentsDefinition entry must include 'id', 'name', and 'description' properties"
                    }
                    if ($agent.name.Length -gt 256) { throw "Connected agent name exceeds 256 characters" }
                    if ($agent.description.Length -gt 512) { throw "Connected agent description exceeds 512 characters" }
                }
                return $true
            })]
        [object[]]$ConnectedAgentsDefinition,

        # Code Interpreter Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableCodeInterpreter,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateCount(0, 20)]
        [string[]]$CodeInterpreterFileIds,

        # File Search Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableFileSearch,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateCount(1, 1)]
        [string[]]$FileSearchVectorStoreIds,

        # Azure AI Search Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableAzureAiSearch,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateScript({
                foreach ($index in $_) {
                    $requiredProps = @('index_connection_id', 'index_name')
                    foreach ($prop in $requiredProps) {
                        if (-not $index.$prop) { throw "Azure AI Search index missing required property: $prop" }
                    }
                }
                return $true
            })]
        [object[]]$AzureAiSearchIndexes,

        # Function Tool Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableFunctionTool,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [ValidateLength(1, 64)]
        [string]$FunctionName,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 1024)]
        [string]$FunctionDescription,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateScript({
                if ($_.type -ne 'object') { throw "Function parameters must have type 'object'" }
                if (-not $_.properties) { throw "Function parameters must include 'properties'" }
                return $true
            })]
        [hashtable]$FunctionParameters,

        # OpenAPI Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableOpenApi,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) { throw "OpenAPI definition file not found: $_" }
                $extension = [System.IO.Path]::GetExtension($_).ToLower()
                if ($extension -ne '.json') {
                    throw "OpenAPI file must be JSON format (.json). YAML is not supported."
                }
                return $true
            })]
        [string]$OpenApiDefinitionFile,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 64)]
        [string]$OpenApiName,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 1024)]
        [string]$OpenApiDescription,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateSet('Anonymous', 'Connection', 'ManagedIdentity')]
        [string]$OpenApiAuthType,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$OpenApiConnectionId,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidatePattern('^https?://')]
        [string]$OpenApiManagedAudience
    )

    begin {
        Write-Verbose "Starting New-MetroAIResource"

        # Ensure context is set
        if (-not $script:MetroContext) {
            throw "Metro AI context not set. Use Set-MetroAIContext first."
        }

        Write-Verbose "Using $($script:MetroContext.ApiType) API at $($script:MetroContext.Endpoint)"
    }

    process {
        try {
            # Handle JSON file input
            if ($PSCmdlet.ParameterSetName -eq 'Json') {
                Write-Verbose "Processing input file: $InputFile"

                try {
                    $body = Get-Content -Path $InputFile -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 100 -NoEnumerate -ErrorAction Stop
                    Write-Verbose "Successfully parsed JSON input file"
                }
                catch {
                    throw "Failed to parse JSON input file '$InputFile': $($_.Exception.Message)"
                }

                # Clean up auto-generated properties
                $body = Remove-MetroAIAutoGeneratedProperties -InputObject $body

                # Extract name from JSON for confirmation message
                $resourceName = if ($body.name) { $body.name } else { "Unnamed Resource" }
                $resourceModel = if ($body.model) { $body.model } else { "Unknown Model" }

                $confirmMessage = "Create new $($script:MetroContext.ApiType) '$resourceName' with model '$resourceModel' from file '$InputFile'"
                if ($body.tools -and $body.tools.Count -gt 0) {
                    $toolsList = ($body.tools | ForEach-Object { $_.type }) -join ', '
                    $confirmMessage += " and tools: $toolsList"
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'InputObject') {
                # Handle pipeline input for copying existing resources
                Write-Verbose "Processing pipeline input object for copying"

                if (-not $InputObject.id) {
                    throw "Input object must have an 'id' property"
                }

                Write-Verbose "Copying resource from ID: $($InputObject.id)"

                # Clean up auto-generated properties and convert to manageable object
                $body = Remove-MetroAIAutoGeneratedProperties -InputObject $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json

                # Override with any explicitly provided parameters (Name and Model are required for InputObject parameter set)
                if ($PSBoundParameters.ContainsKey('Model')) {
                    $body.model = $Model
                    Write-Verbose "Overriding model with: $Model"
                }
                if ($PSBoundParameters.ContainsKey('Name')) {
                    $body.name = $Name
                    Write-Verbose "Setting new name: $Name"
                }
                else {
                    throw "Name parameter is required when copying from InputObject"
                }

                # Override other optional parameters if provided
                if ($PSBoundParameters.ContainsKey('Description')) { $body.description = $Description }
                if ($PSBoundParameters.ContainsKey('Instructions')) { $body.instructions = $Instructions }
                if ($PSBoundParameters.ContainsKey('Metadata')) { $body.metadata = $Metadata }
                if ($PSBoundParameters.ContainsKey('ResponseFormat')) { $body.response_format = $ResponseFormat }
                if ($PSBoundParameters.ContainsKey('Temperature')) { $body.temperature = $Temperature }
                if ($PSBoundParameters.ContainsKey('TopP')) { $body.top_p = $TopP }

                $confirmMessage = "Create new $($script:MetroContext.ApiType) '$Name' as copy of '$($InputObject.name)' (ID: $($InputObject.id))"
                if ($body.tools -and $body.tools.Count -gt 0) {
                    $toolsList = ($body.tools | ForEach-Object { $_.type }) -join ', '
                    $confirmMessage += " with tools: $toolsList"
                }
            }
            else {
                # Handle parameter-based creation (existing logic)
                Write-Verbose "Processing parameter-based creation with Model: $Model, Name: $Name"

                # Enhanced parameter validation with detailed error messages
                if ($EnableConnectedAgent -and $ConnectedAgentsDefinition) {
                    throw "Cannot use both -EnableConnectedAgent and -ConnectedAgentsDefinition simultaneously. Choose one approach."
                }

                if ($EnableConnectedAgent) {
                    $requiredParams = @('ConnectedAgentId', 'ConnectedAgentName', 'ConnectedAgentDescription')
                    foreach ($param in $requiredParams) {
                        if (-not $PSBoundParameters[$param]) {
                            throw "Parameter '$param' is required when using -EnableConnectedAgent."
                        }
                    }

                    # Validate connected agent exists with detailed error handling
                    Write-Verbose "Validating connected agent: $ConnectedAgentId"
                    try {
                        $connectedAgent = Get-MetroAIResource -AssistantId $ConnectedAgentId -ErrorAction Stop
                        Write-Verbose "Connected agent '$($connectedAgent.name)' validated successfully"
                    }
                    catch {
                        throw "Connected agent '$ConnectedAgentId' not found or inaccessible. Verify the ID exists and you have access: $($_.Exception.Message)"
                    }
                }

                if ($ConnectedAgentsDefinition) {
                    Write-Verbose "Validating $($ConnectedAgentsDefinition.Count) connected agents"
                    foreach ($agent in $ConnectedAgentsDefinition) {
                        try {
                            $connectedAgent = Get-MetroAIResource -AssistantId $agent.id -ErrorAction Stop
                            Write-Verbose "Connected agent '$($agent.name)' (ID: $($agent.id)) validated successfully"
                        }
                        catch {
                            throw "Connected agent '$($agent.id)' not found or inaccessible. Verify the ID exists and you have access: $($_.Exception.Message)"
                        }
                    }
                }

                # Tool-specific validation with helpful error messages
                if ($EnableCodeInterpreter -and -not $PSBoundParameters.ContainsKey('CodeInterpreterFileIds')) {
                    throw "CodeInterpreterFileIds parameter is required when EnableCodeInterpreter is specified. Provide an array of file IDs or use an empty array @() if no files are needed initially."
                }

                if ($EnableFileSearch -and -not $FileSearchVectorStoreIds) {
                    throw "FileSearchVectorStoreIds parameter is required when EnableFileSearch is specified."
                }

                if ($EnableAzureAiSearch -and -not $AzureAiSearchIndexes) {
                    throw "AzureAiSearchIndexes parameter is required when EnableAzureAiSearch is specified."
                }

                if ($EnableFileSearch -and -not $FileSearchVectorStoreIds) {
                    throw "FileSearchVectorStoreIds parameter is required when EnableFileSearch is specified."
                }

                if ($EnableFunctionTool) {
                    $requiredFuncParams = @('FunctionName', 'FunctionDescription', 'FunctionParameters')
                    foreach ($param in $requiredFuncParams) {
                        if (-not $PSBoundParameters[$param]) {
                            throw "Parameter '$param' is required when using -EnableFunctionTool"
                        }
                    }
                }

                if ($EnableOpenApi) {
                    $requiredApiParams = @('OpenApiDefinitionFile', 'OpenApiName', 'OpenApiDescription', 'OpenApiAuthType')
                    foreach ($param in $requiredApiParams) {
                        if (-not $PSBoundParameters[$param]) {
                            throw "Parameter '$param' is required when using -EnableOpenApi"
                        }
                    }

                    if ($OpenApiAuthType -eq 'Connection' -and -not $OpenApiConnectionId) {
                        throw "OpenApiConnectionId is required when OpenApiAuthType is 'Connection'"
                    }

                    if ($OpenApiAuthType -eq 'ManagedIdentity' -and -not $OpenApiManagedAudience) {
                        throw "OpenApiManagedAudience is required when OpenApiAuthType is 'ManagedIdentity'"
                    }
                }

                if ($EnableBingGrounding -and -not $BingConnectionId) {
                    throw "BingConnectionId is required when EnableBingGrounding is specified. Only connection-based authentication is supported for Bing grounding."
                }

                # Temperature and TopP mutual exclusivity check
                if ($PSBoundParameters.ContainsKey('Temperature') -and $PSBoundParameters.ContainsKey('TopP')) {
                    Write-Warning "Both Temperature and TopP specified. The API may use only one. Consider using only Temperature or only TopP for predictable behavior."
                }

                # Build request body with proper null checking
                $body = @{
                    model = $Model
                    name  = $Name
                }

                # Add optional core properties only if they have values
                if ($Description) { $body.description = $Description }
                if ($Instructions) { $body.instructions = $Instructions }
                if ($Metadata -and $Metadata.Count -gt 0) { $body.metadata = $Metadata }
                if ($ResponseFormat) { $body.response_format = $ResponseFormat }
                if ($PSBoundParameters.ContainsKey('Temperature')) { $body.temperature = $Temperature }
                if ($PSBoundParameters.ContainsKey('TopP')) { $body.top_p = $TopP }

                # Assemble tools and resources using Lists for better performance
                $tools = [System.Collections.Generic.List[hashtable]]::new()
                $toolResources = @{}

                # Connected Agent Tools
                if ($EnableConnectedAgent) {
                    $tools.Add(@{
                            type            = 'connected_agent'
                            connected_agent = @{
                                id          = $ConnectedAgentId
                                name        = $ConnectedAgentName
                                description = $ConnectedAgentDescription
                            }
                        })
                    Write-Verbose "Added connected agent tool: $ConnectedAgentName"
                }

                if ($ConnectedAgentsDefinition) {
                    foreach ($agent in $ConnectedAgentsDefinition) {
                        $tools.Add(@{
                                type            = 'connected_agent'
                                connected_agent = @{
                                    id          = $agent.id
                                    name        = $agent.name
                                    description = $agent.description
                                }
                            })
                        Write-Verbose "Added connected agent tool: $($agent.name)"
                    }
                }

                # Code Interpreter Tool
                if ($EnableCodeInterpreter) {
                    $tools.Add(@{ type = 'code_interpreter' })
                    # Use empty array if no file IDs provided
                    $fileIds = if ($CodeInterpreterFileIds) { $CodeInterpreterFileIds } else { @() }
                    $toolResources.code_interpreter = @{ file_ids = $fileIds }
                    Write-Verbose "Added code interpreter tool with $($fileIds.Count) files"
                }

                # File Search Tool
                if ($EnableFileSearch) {
                    $tools.Add(@{ type = 'file_search' })
                    $toolResources.file_search = @{ vector_store_ids = $FileSearchVectorStoreIds }
                    Write-Verbose "Added file search tool with $($FileSearchVectorStoreIds.Count) vector stores"
                }

                # Azure AI Search Tool
                if ($EnableAzureAiSearch) {
                    $tools.Add(@{ type = 'azure_ai_search' })
                    $toolResources.azure_ai_search = @{ indexes = $AzureAiSearchIndexes }
                    Write-Verbose "Added Azure AI Search tool with $($AzureAiSearchIndexes.Count) indexes"
                }

                # Function Tool
                if ($EnableFunctionTool) {
                    $tools.Add(@{
                            type     = 'function'
                            function = @{
                                name        = $FunctionName
                                description = $FunctionDescription
                                parameters  = $FunctionParameters
                            }
                        })
                    Write-Verbose "Added function tool: $FunctionName"
                }

                # OpenAPI Tool
                if ($EnableOpenApi) {
                    Write-Verbose "Loading OpenAPI specification from: $OpenApiDefinitionFile"

                    try {
                        $specContent = Get-Content -Path $OpenApiDefinitionFile -Raw -ErrorAction Stop
                        $spec = $specContent | ConvertFrom-Json -ErrorAction Stop

                        $auth = switch ($OpenApiAuthType) {
                            'Anonymous' { @{ type = 'anonymous' } }
                            'Connection' { @{ type = 'connection'; connection_id = $OpenApiConnectionId } }
                            'ManagedIdentity' { @{ type = 'managed_identity'; security_scheme = @{ audience = $OpenApiManagedAudience } } }
                        }

                        $tools.Add(@{
                                type    = 'openapi'
                                openapi = @{
                                    name        = $OpenApiName
                                    description = $OpenApiDescription
                                    spec        = $spec
                                    auth        = $auth
                                }
                            })
                        Write-Verbose "Added OpenAPI tool: $OpenApiName ($OpenApiAuthType auth)"
                    }
                    catch {
                        throw "Failed to process OpenAPI definition file '$OpenApiDefinitionFile': $($_.Exception.Message)"
                    }
                }

                # Bing Grounding Tool - Connection-based only with correct payload structure
                if ($EnableBingGrounding) {
                    Write-Verbose "Configuring Bing grounding tool with connection: $BingConnectionId"

                    $tools.Add(@{
                            type           = 'bing_grounding'
                            bing_grounding = @{
                                connections = @(
                                    @{
                                        connection_id = $BingConnectionId
                                    }
                                )
                            }
                        })
                    Write-Verbose "Added Bing grounding tool with connection ID: $BingConnectionId"
                }

                # Add tools and resources to body if any exist
                if ($tools.Count -gt 0) {
                    $body.tools = $tools.ToArray()
                    Write-Verbose "Total tools configured: $($tools.Count)"
                }

                if ($toolResources.Count -gt 0) {
                    $body.tool_resources = $toolResources
                    Write-Verbose "Tool resources configured for: $($toolResources.Keys -join ', ')"
                }

                # Create resource with confirmation
                $resourceType = $script:MetroContext.ApiType
                $confirmMessage = "Create new $resourceType '$Name' with model '$Model'"
                if ($tools.Count -gt 0) {
                    $toolsList = ($tools | ForEach-Object { $_.type }) -join ', '
                    $confirmMessage += " and tools: $toolsList"
                }
            }

            # Execute the creation with confirmation
            if ($PSCmdlet.ShouldProcess($confirmMessage, "New-MetroAIResource")) {
                Write-Verbose "Creating resource..."
                Write-Verbose "Request payload: $($body | ConvertTo-Json -Depth 100 -Compress)"

                $invokeParams = @{
                    Service     = 'assistants'
                    Operation   = 'create'
                    Method      = 'Post'
                    ContentType = 'application/json'
                    Body        = $body
                }

                $result = Invoke-MetroAIApiCall @invokeParams

                if ($result -and $result.id) {
                    $resultName = if ($body.name) { $body.name } else { $result.id }
                    Write-Information "Successfully created $($script:MetroContext.ApiType) '$resultName' with ID: $($result.id)" -InformationAction Continue

                    # Add some useful output for the user
                    if ($result.tools -and $result.tools.Count -gt 0) {
                        Write-Information "Configured tools: $($result.tools | ForEach-Object { $_.type })" -InformationAction Continue
                    }

                    Write-Verbose "Resource creation completed successfully"
                    return $result
                }
                else {
                    throw "Resource creation appeared to succeed but no ID was returned in the response. This may indicate a service issue."
                }
            }
        }
        catch {
            $errorName = if ($PSCmdlet.ParameterSetName -eq 'Json') {
                if ($body.name) { $body.name } else { "Resource from $InputFile" }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'InputObject') {
                $Name
            }
            else {
                $Name
            }
            $errorMessage = "Failed to create Metro AI resource '$errorName': $($_.Exception.Message)"
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
}


function Set-MetroAIResource {
    <#
    .SYNOPSIS
        Updates an existing Metro AI agent or assistant resource with comprehensive tool support.
    .DESCRIPTION
        Updates an Azure AI agent or assistant with various tools including connected agents, code interpreter,
        file search, Azure AI Search, custom functions, OpenAPI integrations, and Bing grounding.
        Can update from JSON file, specify individual parameters, or accept pipeline input from Get-MetroAIResource.
    .PARAMETER InputObject
        Pipeline input object from Get-MetroAIResource. When used, the object's properties are used for the update.
    .PARAMETER AssistantId
        The ID of the agent/assistant resource to update.
    .PARAMETER InputFile
        Path to a JSON file containing the complete resource definition to update.
    .PARAMETER Model
        The model identifier (e.g., 'gpt-4', 'gpt-4-turbo', 'gpt-35-turbo').
    .PARAMETER Name
        The name of the agent/assistant resource.
    .PARAMETER Description
        Optional description for the resource (max 512 characters).
    .PARAMETER Instructions
        System instructions that guide the agent's behavior (max 256,000 characters).
    .PARAMETER Metadata
        Optional metadata as key-value pairs (max 16 pairs, keys/values max 64 chars each).
    .PARAMETER ResponseFormat
        Response format specification. Use 'text' or structured format definitions.
    .PARAMETER Temperature
        Sampling temperature between 0.0 (deterministic) and 2.0 (most random).
    .PARAMETER TopP
        Nucleus sampling parameter between 0.0 and 1.0. Alternative to temperature.
    .PARAMETER EnableBingGrounding
        Enable Bing search grounding for real-time information retrieval.
    .PARAMETER BingConnectionId
        Connection ID for Bing Search API. Required when EnableBingGrounding is used.
    .PARAMETER AddBingGrounding
        Switch to add Bing grounding to existing tools without replacing them.
    .PARAMETER RemoveBingGrounding
        Switch to remove Bing grounding from existing tools.
    .PARAMETER ClearAllTools
        Switch to remove all existing tools before applying new configuration.
    .EXAMPLE
        Set-MetroAIResource -AssistantId 'asst-123' -InputFile './updated-assistant.json'
    .EXAMPLE
        Set-MetroAIResource -AssistantId 'asst-123' -EnableBingGrounding -BingConnectionId 'bing-conn-1'
    .EXAMPLE
        $Agent = Get-MetroAIAgent -AssistantId 'asst-123'
        $Agent.Description = 'Updated description'
        $Agent | Set-MetroAIAgent
    .EXAMPLE
        Get-MetroAIAgent -AssistantId 'asst-123' | Set-MetroAIAgent -Name 'Updated Name'
    .NOTES
        When using InputFile or InputObject, individual parameters override properties from the input source.
    #>
    [Alias("Set-MetroAIAgent")]
    [Alias("Set-MetroAIAssistant")]
    [CmdletBinding(DefaultParameterSetName = 'Parameters', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'InputObject', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$AssistantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Json')]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) { throw "Input file not found: $_" }
                $extension = [System.IO.Path]::GetExtension($_).ToLower()
                if ($extension -ne '.json') { throw "Input file must be JSON format (.json)" }
                return $true
            })]
        [string]$InputFile,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(1, 256)]
        [string]$Name,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(0, 512)]
        [string]$Description,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(0, 256000)]
        [string]$Instructions,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateScript({
                if ($_.Count -gt 16) { throw "Maximum 16 metadata entries allowed" }
                foreach ($key in $_.Keys) {
                    if ($key.Length -gt 64) { throw "Metadata key '$key' exceeds 64 character limit" }
                    if ($_[$key].ToString().Length -gt 512) { throw "Metadata value for '$key' exceeds 512 character limit" }
                }
                return $true
            })]
        [hashtable]$Metadata,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [string]$ResponseFormat,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateRange(0.0, 2.0)]
        [double]$Temperature,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateRange(0.0, 1.0)]
        [double]$TopP,

        # Bing Grounding Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$EnableBingGrounding,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [string]$BingConnectionId,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$AddBingGrounding,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$RemoveBingGrounding,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$ClearAllTools
    )

    begin {
        Write-Verbose "Starting Set-MetroAIResource for Assistant ID: $AssistantId"

        # Ensure context is set
        if (-not $script:MetroContext) {
            throw "Metro AI context not set. Use Set-MetroAIContext first."
        }
    }

    process {
        try {
            # Validate mutually exclusive Bing grounding options
            $bingOptions = @($EnableBingGrounding, $AddBingGrounding, $RemoveBingGrounding) | Where-Object { $_ }
            if ($bingOptions.Count -gt 1) {
                throw "Cannot use multiple Bing grounding options simultaneously. Choose one: -EnableBingGrounding, -AddBingGrounding, or -RemoveBingGrounding."
            }

            # Validate Bing connection ID is provided when needed
            if (($EnableBingGrounding -or $AddBingGrounding) -and -not $BingConnectionId) {
                throw "BingConnectionId is required when using -EnableBingGrounding or -AddBingGrounding."
            }

            if ($PSCmdlet.ParameterSetName -eq 'Json') {
                # Handle JSON file input
                Write-Verbose "Processing input file: $InputFile"

                try {
                    $requestBody = Get-Content -Path $InputFile -Raw -ErrorAction Stop | ConvertFrom-Json -NoEnumerate -Depth 100 -ErrorAction Stop
                    Write-Verbose "Successfully parsed JSON input file"
                }
                catch {
                    throw "Failed to parse JSON input file '$InputFile': $($_.Exception.Message)"
                }

                # Extract assistant ID from JSON if present, otherwise use parameter
                if ($PSBoundParameters['AssistantId']) {
                    $targetAssistantId = $AssistantId
                }
                elseif ($requestBody.id) {
                    $targetAssistantId = $requestBody.id
                }
                else {
                    throw "AssistantId must be provided either as a parameter or in the JSON file"
                }

                # Clean up auto-generated properties
                $requestBody = Remove-MetroAIAutoGeneratedProperties -InputObject $requestBody

                $confirmMessage = "Update assistant '$targetAssistantId' from file '$InputFile'"
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'InputObject') {
                # Handle pipeline input from Get-MetroAIResource
                Write-Verbose "Processing pipeline input object"

                if (-not $InputObject.id) {
                    throw "Input object must have an 'id' property"
                }

                $targetAssistantId = $InputObject.id

                # Clean up auto-generated properties and convert to manageable object
                $requestBody = Remove-MetroAIAutoGeneratedProperties -InputObject $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json

                # Override with any explicitly provided parameters
                if ($PSBoundParameters.ContainsKey('Model')) { $requestBody.model = $Model }
                if ($PSBoundParameters.ContainsKey('Name')) { $requestBody.name = $Name }
                if ($PSBoundParameters.ContainsKey('Description')) { $requestBody.description = $Description }
                if ($PSBoundParameters.ContainsKey('Instructions')) { $requestBody.instructions = $Instructions }
                if ($PSBoundParameters.ContainsKey('Metadata')) { $requestBody.metadata = $Metadata }
                if ($PSBoundParameters.ContainsKey('ResponseFormat')) { $requestBody.response_format = $ResponseFormat }
                if ($PSBoundParameters.ContainsKey('Temperature')) { $requestBody.temperature = $Temperature }
                if ($PSBoundParameters.ContainsKey('TopP')) { $requestBody.top_p = $TopP }

                # Handle tools configuration for pipeline input
                $currentTools = if ($requestBody.tools) { $requestBody.tools } else { @() }
                $newTools = [System.Collections.Generic.List[object]]::new()

                if ($ClearAllTools) {
                    Write-Verbose "Clearing all existing tools"
                    # Start with empty tools array
                }
                else {
                    # Preserve existing tools unless specifically modifying Bing grounding
                    foreach ($tool in $currentTools) {
                        if ($tool.type -eq 'bing_grounding' -and ($EnableBingGrounding -or $AddBingGrounding -or $RemoveBingGrounding)) {
                            # Skip existing Bing grounding tools when we're modifying them
                            Write-Verbose "Removing existing Bing grounding tool for reconfiguration"
                            continue
                        }
                        $newTools.Add($tool)
                    }
                }

                # Add Bing grounding if requested
                if ($EnableBingGrounding -or $AddBingGrounding) {
                    Write-Verbose "Adding Bing grounding tool with connection: $BingConnectionId"

                    $bingTool = @{
                        type           = 'bing_grounding'
                        bing_grounding = @{
                            connections = @(
                                @{
                                    connection_id = $BingConnectionId
                                }
                            )
                        }
                    }
                    $newTools.Add($bingTool)
                    Write-Verbose "Added Bing grounding tool"
                }

                # Set tools in request body
                $requestBody.tools = $newTools.ToArray()

                # Build confirmation message
                $changes = @()
                if ($PSBoundParameters.ContainsKey('Model')) { $changes += "model updated" }
                if ($PSBoundParameters.ContainsKey('Name')) { $changes += "name updated" }
                if ($PSBoundParameters.ContainsKey('Description')) { $changes += "description updated" }
                if ($PSBoundParameters.ContainsKey('Instructions')) { $changes += "instructions updated" }
                if ($EnableBingGrounding -or $AddBingGrounding) { $changes += "add Bing grounding" }
                if ($RemoveBingGrounding) { $changes += "remove Bing grounding" }
                if ($ClearAllTools) { $changes += "clear all tools" }

                $confirmMessage = "Update assistant '$targetAssistantId' from pipeline input"
                if ($changes.Count -gt 0) {
                    $confirmMessage += " with changes: $($changes -join ', ')"
                }
            }
            else {
                # Handle parameter-based updates
                Write-Verbose "Processing parameter-based update"

                # Get current resource to preserve existing configuration
                try {
                    $currentResource = Get-MetroAIResource -AssistantId $AssistantId -ErrorAction Stop
                    Write-Verbose "Retrieved current resource configuration"
                }
                catch {
                    throw "Failed to retrieve current resource '$AssistantId': $($_.Exception.Message). Verify the ID exists and you have access."
                }

                $targetAssistantId = $AssistantId
                $requestBody = @{}

                # Preserve existing values and update only specified parameters
                if ($Model) { $requestBody.model = $Model } else { $requestBody.model = $currentResource.model }
                if ($Name) { $requestBody.name = $Name } else { $requestBody.name = $currentResource.name }
                if ($PSBoundParameters.ContainsKey('Description')) { $requestBody.description = $Description } elseif ($currentResource.description) { $requestBody.description = $currentResource.description }
                if ($PSBoundParameters.ContainsKey('Instructions')) { $requestBody.instructions = $Instructions } elseif ($currentResource.instructions) { $requestBody.instructions = $currentResource.instructions }
                if ($PSBoundParameters.ContainsKey('Metadata')) { $requestBody.metadata = $Metadata } elseif ($currentResource.metadata) { $requestBody.metadata = $currentResource.metadata }
                if ($PSBoundParameters.ContainsKey('ResponseFormat')) { $requestBody.response_format = $ResponseFormat } elseif ($currentResource.response_format) { $requestBody.response_format = $currentResource.response_format }
                if ($PSBoundParameters.ContainsKey('Temperature')) { $requestBody.temperature = $Temperature } elseif ($null -ne $currentResource.temperature) { $requestBody.temperature = $currentResource.temperature }
                if ($PSBoundParameters.ContainsKey('TopP')) { $requestBody.top_p = $TopP } elseif ($null -ne $currentResource.top_p) { $requestBody.top_p = $currentResource.top_p }

                # Handle tools configuration
                $currentTools = if ($currentResource.tools) { $currentResource.tools } else { @() }
                $newTools = [System.Collections.Generic.List[object]]::new()

                if ($ClearAllTools) {
                    Write-Verbose "Clearing all existing tools"
                    # Start with empty tools array
                }
                else {
                    # Preserve existing tools unless specifically modifying Bing grounding
                    foreach ($tool in $currentTools) {
                        if ($tool.type -eq 'bing_grounding' -and ($EnableBingGrounding -or $AddBingGrounding -or $RemoveBingGrounding)) {
                            # Skip existing Bing grounding tools when we're modifying them
                            Write-Verbose "Removing existing Bing grounding tool for reconfiguration"
                            continue
                        }
                        $newTools.Add($tool)
                    }
                }

                # Add Bing grounding if requested
                if ($EnableBingGrounding -or $AddBingGrounding) {
                    Write-Verbose "Adding Bing grounding tool with connection: $BingConnectionId"

                    $bingTool = @{
                        type           = 'bing_grounding'
                        bing_grounding = @{
                            connections = @(
                                @{
                                    connection_id = $BingConnectionId
                                }
                            )
                        }
                    }
                    $newTools.Add($bingTool)
                    Write-Verbose "Added Bing grounding tool"
                }

                # Set tools in request body
                $requestBody.tools = $newTools.ToArray()

                # Preserve tool_resources if they exist
                if ($currentResource.tool_resources) {
                    $requestBody.tool_resources = $currentResource.tool_resources
                }

                # Build confirmation message
                $confirmMessage = "Update assistant '$AssistantId'"
                $changes = @()

                if ($Model -and $Model -ne $currentResource.model) { $changes += "model: $($currentResource.model) → $Model" }
                if ($Name -and $Name -ne $currentResource.name) { $changes += "name: $($currentResource.name) → $Name" }
                if ($EnableBingGrounding -or $AddBingGrounding) { $changes += "add Bing grounding" }
                if ($RemoveBingGrounding) { $changes += "remove Bing grounding" }
                if ($ClearAllTools) { $changes += "clear all tools" }

                if ($changes.Count -gt 0) {
                    $confirmMessage += " with changes: $($changes -join ', ')"
                }
            }

            # Execute the update with confirmation
            if ($PSCmdlet.ShouldProcess($confirmMessage, "Set-MetroAIResource")) {
                Write-Verbose "Updating resource..."
                Write-Verbose "Request payload: $($requestBody | ConvertTo-Json -Depth 100 -Compress)"

                $invokeParams = @{
                    Service     = 'assistants'
                    Operation   = 'create'
                    Path        = $targetAssistantId
                    Method      = 'Post'
                    ContentType = 'application/json'
                    Body        = $requestBody
                }

                $result = Invoke-MetroAIApiCall @invokeParams

                if ($result -and $result.id) {
                    Write-Information "Successfully updated assistant '$($result.id)'" -InformationAction Continue

                    # Provide feedback about tools configuration
                    if ($result.tools -and $result.tools.Count -gt 0) {
                        $toolTypes = ($result.tools | ForEach-Object { $_.type }) -join ', '
                        Write-Information "Current tools: $toolTypes" -InformationAction Continue
                    }
                    else {
                        Write-Information "No tools configured" -InformationAction Continue
                    }

                    Write-Verbose "Resource update completed successfully"
                    return $result
                }
                else {
                    throw "Resource update appeared to succeed but no ID was returned in the response. This may indicate a service issue."
                }
            }
        }
        catch {
            $errorMessage = "Failed to update Metro AI resource '$AssistantId': $($_.Exception.Message)"
            Write-Error $errorMessage -ErrorAction Stop
        }
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

