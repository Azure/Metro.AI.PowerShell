function New-MetroAIResource {
    <#
    .SYNOPSIS
        Creates a new Metro AI agent or assistant resource with comprehensive tool support.
    .DESCRIPTION
        Creates an Azure AI agent or assistant with various tools including connected agents, code interpreter,
        file search, Azure AI Search, custom functions, OpenAPI integrations, and MCP (Model Context Protocol) servers.
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
    .PARAMETER EnableMcp
        Enable Model Context Protocol (MCP) server integration.
    .PARAMETER McpServerLabel
        Unique label/name for the MCP server (max 256 characters).
    .PARAMETER McpServerUrl
        URL of the MCP server endpoint. Must start with http:// or https://.
    .PARAMETER McpRequireApproval
        Approval policy for MCP server actions: 'never', 'once', or 'always'. Default is 'never'.
    .PARAMETER McpServersConfiguration
        Array of MCP server configurations. Each must have 'server_label', 'server_url', and optionally 'require_approval' and 'allowed_tools' properties.
        The 'allowed_tools' property should be an array of strings specifying which tools the agent can use from that MCP server.
    .EXAMPLE
        New-MetroAIResource -Model 'gpt-4.1' -Name 'MyAssistant' -Description 'General purpose assistant'
    .EXAMPLE
        New-MetroAIResource -InputFile './existing-assistant.json'
    .EXAMPLE
        # Copy an existing agent with a new name
        $Agent = Get-MetroAIAgent -AssistantId 'asst-123'
        $Agent | New-MetroAIAgent -Name 'CopiedAgent'
    .EXAMPLE
        New-MetroAIResource -Model 'gpt-4.1' -Name 'CodeHelper' -EnableCodeInterpreter -CodeInterpreterFileIds @('file-123')
    .EXAMPLE
        # Create assistant with MCP server integration
        New-MetroAIResource -Model 'gpt-4.1' -Name 'MCPBot' -EnableMcp -McpServerLabel 'DatabaseServer' -McpServerUrl 'https://api.example.com/mcp' -McpRequireApproval 'once'
    .EXAMPLE
        # Create assistant with multiple MCP servers
        $mcpServers = @(
            @{ server_label = 'WeatherAPI'; server_url = 'https://weather.example.com/mcp'; require_approval = 'never' },
            @{ server_label = 'DatabaseAPI'; server_url = 'https://db.example.com/mcp'; require_approval = 'once'; allowed_tools = @('query_db', 'update_record') }
        )
        New-MetroAIResource -Model 'gpt-4.1' -Name 'MultiMCPBot' -McpServersConfiguration $mcpServers
    .EXAMPLE
        # Create assistant, then add Bing grounding
        $assistant = New-MetroAIResource -Model 'gpt-4.1' -Name 'SearchBot'
        Set-MetroAIResource -AssistantId $assistant.id -EnableBingGrounding -BingConnectionId 'bing-search-connection'
    .EXAMPLE
        # Multi-tool agent with various capabilities including MCP
        New-MetroAIResource -Model 'gpt-4.1' -Name 'MultiToolAgent' `
            -EnableCodeInterpreter -CodeInterpreterFileIds @('file-123') `
            -EnableAzureAiSearch -AzureAiSearchIndexes @(@{ index_connection_id='search-conn'; index_name='docs'; query_type='semantic'; top_k=5 }) `
            -EnableMcp -McpServerLabel 'CustomAPI' -McpServerUrl 'https://api.example.com/mcp'
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
        [string]$OpenApiManagedAudience,

        # MCP Server Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [switch]$EnableMcp,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateLength(1, 256)]
        [string]$McpServerLabel,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidatePattern('^https?://')]
        [ValidateNotNullOrEmpty()]
        [string]$McpServerUrl,

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateSet('never', 'once', 'always')]
        [string]$McpRequireApproval = 'never',

        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateScript({
                foreach ($server in $_) {
                    if (-not ($server.server_label -and $server.server_url)) {
                        throw "Each McpServersConfiguration entry must include 'server_label' and 'server_url' properties"
                    }
                    if ($server.server_label.Length -gt 256) { throw "MCP server label exceeds 256 characters" }
                    if ($server.server_url -notmatch '^https?://') { throw "MCP server URL must start with http:// or https://" }
                    if ($server.require_approval -and $server.require_approval -notin @('never', 'once', 'always')) {
                        throw "MCP server require_approval must be 'never', 'once', or 'always'"
                    }
                    if ($server.allowed_tools -and $server.allowed_tools -isnot [array]) {
                        throw "MCP server allowed_tools must be an array of strings"
                    }
                }
                return $true
            })]
        [object[]]$McpServersConfiguration
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

                if ($EnableMcp -and $McpServersConfiguration) {
                    throw "Cannot use both -EnableMcp and -McpServersConfiguration simultaneously. Choose one approach."
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

                if ($EnableMcp) {
                    $requiredMcpParams = @('McpServerLabel', 'McpServerUrl')
                    foreach ($param in $requiredMcpParams) {
                        if (-not $PSBoundParameters[$param]) {
                            throw "Parameter '$param' is required when using -EnableMcp"
                        }
                    }
                }

                if ($McpServersConfiguration) {
                    Write-Verbose "Validating $($McpServersConfiguration.Count) MCP server configurations"
                    foreach ($server in $McpServersConfiguration) {
                        if (-not ($server.server_label -and $server.server_url)) {
                            throw "Each MCP server configuration must include 'server_label' and 'server_url' properties"
                        }
                        Write-Verbose "MCP server configuration validated: $($server.server_label) at $($server.server_url)"
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
                    $fileIds = if ($CodeInterpreterFileIds -and $CodeInterpreterFileIds.Count -gt 0) {
                        # Force array conversion using the comma operator to handle single items
                        , $CodeInterpreterFileIds
                    }
                    else {
                        @()
                    }
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

                # MCP Server Tool
                if ($EnableMcp) {
                    Write-Verbose "Configuring MCP server tool: $McpServerLabel at $McpServerUrl"

                    $tools.Add(@{
                            type             = 'mcp'
                            server_label     = $McpServerLabel
                            server_url       = $McpServerUrl
                            require_approval = $McpRequireApproval
                        })
                    Write-Verbose "Added MCP server tool: $McpServerLabel with approval policy: $McpRequireApproval"
                }

                if ($McpServersConfiguration) {
                    Write-Verbose "Adding $($McpServersConfiguration.Count) MCP server configurations"
                    foreach ($server in $McpServersConfiguration) {
                        $mcpTool = @{
                            type             = 'mcp'
                            server_label     = $server.server_label
                            server_url       = $server.server_url
                            require_approval = if ($server.require_approval) { $server.require_approval } else { 'never' }
                        }
                        
                        # Add allowed_tools if specified
                        if ($server.allowed_tools) {
                            $mcpTool.allowed_tools = $server.allowed_tools
                            Write-Verbose "Added allowed_tools for MCP server $($server.server_label): $($server.allowed_tools -join ', ')"
                        }
                        
                        $tools.Add($mcpTool)
                        Write-Verbose "Added MCP server tool: $($server.server_label) at $($server.server_url)"
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
