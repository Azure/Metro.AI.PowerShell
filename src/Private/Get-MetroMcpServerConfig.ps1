function Get-MetroMcpServerConfig {
    <#
    .SYNOPSIS
        Retrieves MCP server configuration for the specified assistant.
    .DESCRIPTION
        Reads the assistant definition and returns the MCP server entry that matches the provided label,
        falling back to the single configured server when no label is supplied.
    .PARAMETER AssistantId
        The assistant (agent) identifier.
    .PARAMETER ServerLabel
        Optional label to select a specific MCP server. If omitted and exactly one server exists,
        that server is returned. An error is thrown when multiple servers exist and no label is supplied.
    .OUTPUTS
        Hashtable containing at least `server_label` and, when available, `server_url`.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AssistantId,

        [Parameter(Mandatory = $false)]
        [string]$ServerLabel
    )

    $resource = Get-MetroAIResource -AssistantId $AssistantId -ErrorAction Stop

    $servers = @{}

    if ($resource.tool_resources) {
        $mcpResources = $resource.tool_resources.mcp

        if ($mcpResources) {
            # Handle structure where mcp.servers is a dictionary keyed by server_label
            $serversProperty = $mcpResources.servers
            if ($serversProperty) {
                if ($serversProperty -is [System.Collections.IDictionary]) {
                    foreach ($label in $serversProperty.Keys) {
                        $value = $serversProperty[$label]
                        $servers[$label] = @{
                            server_label     = $label
                            server_url       = if ($value -is [string]) { $value } elseif ($value.server_url) { $value.server_url } else { $null }
                            require_approval = if ($value.require_approval) { $value.require_approval } else { $null }
                        }
                    }
                }
                elseif ($serversProperty -is [System.Collections.IEnumerable]) {
                    foreach ($entry in $serversProperty) {
                        if ($entry) {
                            $label = $entry.server_label
                            if ($label) {
                                $servers[$label] = @{
                                    server_label     = $label
                                    server_url       = $entry.server_url
                                    require_approval = $entry.require_approval
                                }
                            }
                        }
                    }
                }
            }
            elseif ($mcpResources -is [System.Collections.IEnumerable] -and $mcpResources -isnot [string]) {
                foreach ($entry in $mcpResources) {
                    if ($entry) {
                        $label = $entry.server_label
                        if ($label) {
                            $servers[$label] = @{
                                server_label     = $label
                                server_url       = $entry.server_url
                                require_approval = $entry.require_approval
                            }
                        }
                    }
                }
            }
            elseif ($mcpResources.server_label) {
                $servers[$mcpResources.server_label] = @{
                    server_label     = $mcpResources.server_label
                    server_url       = $mcpResources.server_url
                    require_approval = $mcpResources.require_approval
                }
            }
        }
    }

    if ($resource.tools) {
        foreach ($tool in $resource.tools) {
            if ($tool.type -eq 'mcp' -and $tool.server_label) {
                $label = $tool.server_label
                if (-not $servers.ContainsKey($label)) {
                    $servers[$label] = @{ server_label = $label }
                }
                if ($tool.server_url) {
                    $servers[$label].server_url = $tool.server_url
                }
            }
        }
    }

    $resolvedLabel = $ServerLabel
    if (-not $resolvedLabel) {
        if ($servers.Count -eq 1) {
            $resolvedLabel = ($servers.Keys | Select-Object -First 1)
        }
        elseif ($servers.Count -gt 1) {
            throw "Multiple MCP servers are configured for assistant '$AssistantId'. Specify -McpServerLabel or provide -McpToolOverrides."
        }
    }

    if ($resolvedLabel) {
        if ($servers.ContainsKey($resolvedLabel)) {
            return $servers[$resolvedLabel]
        }
        else {
            # Return minimal definition so the label can still be referenced
            return @{ server_label = $resolvedLabel }
        }
    }

    return $null
}
