function Add-MetroMcpServerResource {
    <#
    .SYNOPSIS
        Ensures MCP server definitions exist in the tool_resources collection.
    .DESCRIPTION
        Adds or updates the entry under tool_resources.mcp for the specified server label using the
        array structure required by the Assistants API.
    .PARAMETER ToolResources
        Existing tool_resources hashtable to update.
    .PARAMETER ServerLabel
        Label identifying the MCP server.
    .PARAMETER ServerUrl
        Endpoint URL for the MCP server.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]$ToolResources,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerLabel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerUrl,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers
    )

    if (-not $ToolResources) {
        $ToolResources = @{}
    }

    $mcpEntries = @()

    if ($ToolResources.mcp) {
        $existing = $ToolResources.mcp

        if ($existing -is [System.Collections.IDictionary]) {
            foreach ($key in $existing.Keys) {
                $value = $existing[$key]
                $entry = @{ server_label = $key }
                if ($value -and $value.server_url) { $entry.server_url = $value.server_url }
                if ($value -and $value.headers) { $entry.headers = $value.headers }
                $mcpEntries += $entry
            }
        }
        elseif ($existing -is [System.Collections.IEnumerable] -and $existing -isnot [string]) {
            foreach ($item in $existing) {
                if (-not $item) { continue }
                $label = $item.server_label
                if (-not $label) { continue }
                $entry = @{ server_label = $label }
                if ($item.server_url) { $entry.server_url = $item.server_url }
                if ($item.headers) { $entry.headers = $item.headers }
                $mcpEntries += $entry
            }
        }
        elseif ($existing.server_label) {
            $entry = @{ server_label = $existing.server_label }
            if ($existing.server_url) { $entry.server_url = $existing.server_url }
            if ($existing.headers) { $entry.headers = $existing.headers }
            $mcpEntries += $entry
        }
    }

    $newEntry = @{
        server_label = $ServerLabel
        server_url   = $ServerUrl
    }

    if ($Headers) {
        $newEntry.headers = $Headers
    }

    $existingIndex = $null
    for ($i = 0; $i -lt $mcpEntries.Count; $i++) {
        if ($mcpEntries[$i].server_label -eq $ServerLabel) {
            $existingIndex = $i
            break
        }
    }

    if ($existingIndex -ne $null) {
        $mcpEntries[$existingIndex] = $newEntry
    }
    else {
        $mcpEntries += $newEntry
    }

    $ToolResources.mcp = $mcpEntries

    return $ToolResources
}
