function Set-MetroAIResource {
    <#
    .SYNOPSIS
        Updates an existing Metro AI agent or assistant resource with comprehensive tool support.
    .DESCRIPTION
        Updates an Azure AI agent or assistant with various tools including connected agents, code interpreter,
        file search, Azure AI Search, custom functions, OpenAPI integrations, Bing grounding, and MCP (Model Context Protocol) servers.
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
    .PARAMETER EnableMcp
        Enable Model Context Protocol (MCP) server integration.
    .PARAMETER McpServerLabel
        Unique label/name for the MCP server (max 256 characters).
    .PARAMETER McpServerUrl
        URL of the MCP server endpoint. Must start with http:// or https://.
    .PARAMETER McpRequireApproval
        Approval policy for MCP server actions: 'never', 'once', or 'always'. Default is 'never'.
    .PARAMETER AddMcp
        Switch to add MCP server to existing tools without replacing them.
    .PARAMETER RemoveMcp
        Switch to remove all MCP servers from existing tools.
    .PARAMETER McpServersConfiguration
        Array of MCP server configurations. Each must have 'server_label', 'server_url', and optionally 'require_approval' and 'allowed_tools' properties.
        The 'allowed_tools' property should be an array of strings specifying which tools the agent can use from that MCP server.
    .EXAMPLE
        Set-MetroAIResource -AssistantId 'asst-123' -InputFile './updated-assistant.json'
    .EXAMPLE
        Set-MetroAIResource -AssistantId 'asst-123' -EnableBingGrounding -BingConnectionId 'bing-conn-1'
    .EXAMPLE
        # Add MCP server to existing assistant
        Set-MetroAIResource -AssistantId 'asst-123' -AddMcp -McpServerLabel 'WeatherAPI' -McpServerUrl 'https://weather.example.com/mcp'
    .EXAMPLE
        # Replace all tools with MCP server only
        Set-MetroAIResource -AssistantId 'asst-123' -ClearAllTools -EnableMcp -McpServerLabel 'DatabaseAPI' -McpServerUrl 'https://db.example.com/mcp' -McpRequireApproval 'once'
    .EXAMPLE
        # Add multiple MCP servers
        $mcpServers = @(
            @{ server_label = 'API1'; server_url = 'https://api1.example.com/mcp'; require_approval = 'never' },
            @{ server_label = 'API2'; server_url = 'https://api2.example.com/mcp'; require_approval = 'always' }
        )
        Set-MetroAIResource -AssistantId 'asst-123' -McpServersConfiguration $mcpServers
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

        # Code Interpreter Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$EnableCodeInterpreter,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateCount(0, 20)]
        [string[]]$CodeInterpreterFileIds,

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
        [switch]$ClearAllTools,

        # MCP Server Parameters
        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$EnableMcp,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateLength(1, 256)]
        [string]$McpServerLabel,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidatePattern('^https?://')]
        [ValidateNotNullOrEmpty()]
        [string]$McpServerUrl,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateSet('never', 'once', 'always')]
        [string]$McpRequireApproval = 'never',

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$AddMcp,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
        [switch]$RemoveMcp,

        [Parameter(ParameterSetName = 'Parameters')]
        [Parameter(ParameterSetName = 'InputObject')]
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

            # Validate mutually exclusive MCP options
            $mcpOptions = @($EnableMcp, $AddMcp, $RemoveMcp) | Where-Object { $_ }
            if ($mcpOptions.Count -gt 1) {
                throw "Cannot use multiple MCP options simultaneously. Choose one: -EnableMcp, -AddMcp, or -RemoveMcp."
            }

            # Validate MCP and McpServersConfiguration are not used together
            if (($EnableMcp -or $AddMcp) -and $McpServersConfiguration) {
                throw "Cannot use both individual MCP parameters (-EnableMcp/-AddMcp) and -McpServersConfiguration simultaneously. Choose one approach."
            }

            # Validate Bing connection ID is provided when needed
            if (($EnableBingGrounding -or $AddBingGrounding) -and -not $BingConnectionId) {
                throw "BingConnectionId is required when using -EnableBingGrounding or -AddBingGrounding."
            }

            # Validate MCP parameters are provided when needed
            if (($EnableMcp -or $AddMcp) -and (-not $McpServerLabel -or -not $McpServerUrl)) {
                throw "McpServerLabel and McpServerUrl are required when using -EnableMcp or -AddMcp."
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

                # Handle Code Interpreter configuration for pipeline input
                if ($EnableCodeInterpreter -or $CodeInterpreterFileIds) {
                    # Get existing file IDs from current resource
                    $existingFileIds = @()
                    if ($requestBody.tool_resources -and $requestBody.tool_resources.code_interpreter -and $requestBody.tool_resources.code_interpreter.file_ids) {
                        $existingFileIds = $requestBody.tool_resources.code_interpreter.file_ids
                    }

                    # Convert tool_resources to hashtable if it doesn't exist or recreate it
                    $toolResourcesHash = @{}
                    if ($requestBody.tool_resources) {
                        # Convert existing tool_resources to hashtable
                        $requestBody.tool_resources.PSObject.Properties | ForEach-Object {
                            $toolResourcesHash[$_.Name] = $_.Value
                        }
                    }
                    $requestBody | Add-Member -MemberType NoteProperty -Name "tool_resources" -Value $toolResourcesHash -Force

                    # Use helper function to configure Code Interpreter
                    Set-CodeInterpreterConfiguration -RequestBody $requestBody -ExistingFileIds $existingFileIds -NewFileIds $CodeInterpreterFileIds -EnableCodeInterpreter:$EnableCodeInterpreter
                }

                # Handle tools configuration for pipeline input
                $currentTools = if ($requestBody.tools) { $requestBody.tools } else { @() }
                $newTools = [System.Collections.Generic.List[object]]::new()

                if ($ClearAllTools) {
                    Write-Verbose "Clearing all existing tools"
                    # Start with empty tools array, but add code_interpreter if requested
                    if ($EnableCodeInterpreter) {
                        $newTools.Add(@{ type = "code_interpreter" })
                        Write-Verbose "Added code_interpreter tool"
                    }
                }
                else {
                    # Preserve existing tools unless specifically modifying them
                    foreach ($tool in $currentTools) {
                        if ($tool.type -eq 'bing_grounding' -and ($EnableBingGrounding -or $AddBingGrounding -or $RemoveBingGrounding)) {
                            # Skip existing Bing grounding tools when we're modifying them
                            Write-Verbose "Removing existing Bing grounding tool for reconfiguration"
                            continue
                        }
                        if ($tool.type -eq 'mcp' -and ($EnableMcp -or $AddMcp -or $RemoveMcp)) {
                            # Skip existing MCP tools when we're modifying them
                            Write-Verbose "Removing existing MCP tool for reconfiguration"
                            continue
                        }
                        $newTools.Add($tool)
                    }

                    # Add code_interpreter tool if EnableCodeInterpreter is specified and not already present
                    if ($EnableCodeInterpreter) {
                        $currentToolTypes = $newTools | ForEach-Object { $_.type }

                        if ($currentToolTypes -notcontains "code_interpreter") {
                            $newTools.Add(@{ type = "code_interpreter" })
                            Write-Verbose "Added code_interpreter tool"
                        }
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

                # Add MCP server if requested
                if ($EnableMcp -or $AddMcp) {
                    Write-Verbose "Adding MCP server tool: $McpServerLabel at $McpServerUrl"

                    $mcpTool = @{
                        type             = 'mcp'
                        server_label     = $McpServerLabel
                        server_url       = $McpServerUrl
                        require_approval = $McpRequireApproval
                    }
                    $newTools.Add($mcpTool)
                    Write-Verbose "Added MCP server tool: $McpServerLabel"
                }

                # Add multiple MCP servers if configuration provided
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
                        
                        $newTools.Add($mcpTool)
                        Write-Verbose "Added MCP server tool: $($server.server_label)"
                    }
                }

                # Set tools in request body
                $requestBody.tools = $newTools.ToArray()

                # Build confirmation message
                $changes = @()
                if ($PSBoundParameters.ContainsKey('Model')) { $changes += "model updated" }
                if ($PSBoundParameters.ContainsKey('Name')) { $changes += "name updated" }
                if ($PSBoundParameters.ContainsKey('Description')) { $changes += "description updated" }
                if ($PSBoundParameters.ContainsKey('Instructions')) { $changes += "instructions updated" }
                if ($EnableCodeInterpreter) { $changes += "enable code interpreter" }
                if ($CodeInterpreterFileIds) { $changes += "update code interpreter files" }
                if ($EnableBingGrounding -or $AddBingGrounding) { $changes += "add Bing grounding" }
                if ($RemoveBingGrounding) { $changes += "remove Bing grounding" }
                if ($EnableMcp -or $AddMcp) { $changes += "add MCP server" }
                if ($RemoveMcp) { $changes += "remove MCP servers" }
                if ($McpServersConfiguration) { $changes += "add multiple MCP servers" }
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
                    # Start with empty tools array, but add code_interpreter if requested
                    if ($EnableCodeInterpreter) {
                        $newTools.Add(@{ type = "code_interpreter" })
                        Write-Verbose "Added code_interpreter tool"
                    }
                }
                else {
                    # Preserve existing tools unless specifically modifying them
                    foreach ($tool in $currentTools) {
                        if ($tool.type -eq 'bing_grounding' -and ($EnableBingGrounding -or $AddBingGrounding -or $RemoveBingGrounding)) {
                            # Skip existing Bing grounding tools when we're modifying them
                            Write-Verbose "Removing existing Bing grounding tool for reconfiguration"
                            continue
                        }
                        if ($tool.type -eq 'mcp' -and ($EnableMcp -or $AddMcp -or $RemoveMcp)) {
                            # Skip existing MCP tools when we're modifying them
                            Write-Verbose "Removing existing MCP tool for reconfiguration"
                            continue
                        }
                        $newTools.Add($tool)
                    }

                    # Add code_interpreter tool if EnableCodeInterpreter is specified and not already present
                    if ($EnableCodeInterpreter) {
                        $currentToolTypes = $newTools | ForEach-Object { $_.type }

                        if ($currentToolTypes -notcontains "code_interpreter") {
                            $newTools.Add(@{ type = "code_interpreter" })
                            Write-Verbose "Added code_interpreter tool"
                        }
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

                # Add MCP server if requested
                if ($EnableMcp -or $AddMcp) {
                    Write-Verbose "Adding MCP server tool: $McpServerLabel at $McpServerUrl"

                    $mcpTool = @{
                        type             = 'mcp'
                        server_label     = $McpServerLabel
                        server_url       = $McpServerUrl
                        require_approval = $McpRequireApproval
                    }
                    $newTools.Add($mcpTool)
                    Write-Verbose "Added MCP server tool: $McpServerLabel"
                }

                # Add multiple MCP servers if configuration provided
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
                        
                        $newTools.Add($mcpTool)
                        Write-Verbose "Added MCP server tool: $($server.server_label)"
                    }
                }

                # Set tools in request body
                $requestBody.tools = $newTools.ToArray()

                # Handle tool_resources properly by converting to hashtable
                $toolResourcesHash = @{}
                if ($currentResource.tool_resources) {
                    # Convert existing tool_resources to hashtable
                    $currentResource.tool_resources.PSObject.Properties | ForEach-Object {
                        $toolResourcesHash[$_.Name] = $_.Value
                    }
                }
                $requestBody.tool_resources = $toolResourcesHash

                # Handle Code Interpreter configuration for parameter-based updates
                if ($EnableCodeInterpreter -or $CodeInterpreterFileIds) {
                    # Get existing file IDs from current resource
                    $existingFileIds = @()
                    if ($currentResource.tool_resources -and $currentResource.tool_resources.code_interpreter -and $currentResource.tool_resources.code_interpreter.file_ids) {
                        $existingFileIds = $currentResource.tool_resources.code_interpreter.file_ids
                    }

                    # Use helper function to configure Code Interpreter
                    Set-CodeInterpreterConfiguration -RequestBody $requestBody -ExistingFileIds $existingFileIds -NewFileIds $CodeInterpreterFileIds -EnableCodeInterpreter:$EnableCodeInterpreter
                }

                # Build confirmation message
                $confirmMessage = "Update assistant '$AssistantId'"
                $changes = @()

                if ($Model -and $Model -ne $currentResource.model) { $changes += "model: $($currentResource.model) → $Model" }
                if ($Name -and $Name -ne $currentResource.name) { $changes += "name: $($currentResource.name) → $Name" }
                if ($EnableCodeInterpreter) { $changes += "enable code interpreter" }
                if ($CodeInterpreterFileIds) { $changes += "update code interpreter files" }
                if ($EnableBingGrounding -or $AddBingGrounding) { $changes += "add Bing grounding" }
                if ($RemoveBingGrounding) { $changes += "remove Bing grounding" }
                if ($EnableMcp -or $AddMcp) { $changes += "add MCP server" }
                if ($RemoveMcp) { $changes += "remove MCP servers" }
                if ($McpServersConfiguration) { $changes += "add multiple MCP servers" }
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
