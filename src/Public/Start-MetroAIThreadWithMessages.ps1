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
    .PARAMETER McpServerLabel
        Optional MCP server label to use when invoking the run. If omitted, the single configured server is used.
    .PARAMETER McpToolOverrides
        Advanced override for MCP tool resources, allowing custom headers or approval settings per run.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$AssistantId,
        [Parameter(Mandatory = $true)] [string]$MessageContent,
        [switch]$Async,
        [string]$McpServerLabel,
        [Parameter()][hashtable]$McpToolOverrides
    )
    try {
        $body = @{
            assistant_id = $AssistantId
            thread       = @{
                messages = @(
                    @{
                        role    = "user"
                        content = @(
                            @{
                                type = "text"
                                text = $MessageContent
                            }
                        )
                    }
                )
            }
        }

        $mcpEntry = $null
        if ($McpToolOverrides) {
            if (-not $McpToolOverrides.server_label) {
                throw "McpToolOverrides must include 'server_label'."
            }

            $mcpEntry = @{
                server_label = $McpToolOverrides.server_label
            }

            foreach ($key in @('headers', 'require_approval')) {
                if ($McpToolOverrides.ContainsKey($key) -and $McpToolOverrides[$key]) {
                    $mcpEntry[$key] = $McpToolOverrides[$key]
                }
            }
        }
        else {
            try {
                $resolvedServer = Get-MetroMcpServerConfig -AssistantId $AssistantId -ServerLabel $McpServerLabel
            }
            catch {
                throw "Failed to resolve MCP server configuration for assistant '$AssistantId': $($_.Exception.Message)"
            }

            if ($resolvedServer) {
                $mcpEntry = @{
                    server_label     = $resolvedServer.server_label
                    require_approval = if ($resolvedServer.require_approval) { $resolvedServer.require_approval } else { 'never' }
                }
            }
        }

        if ($mcpEntry) {
            $body.tool_resources = @{ mcp = @($mcpEntry) }
        }
        $response = Invoke-MetroAIApiCall -Service 'threads' -Operation 'thread' -Path "runs" -Method Post -ContentType "application/json" -Body $body
        if (-not $Async) {
            $i = 0
            $terminalStatuses = @('completed', 'failed', 'requires_action', 'cancelled', 'expired')
            do {
                Start-Sleep -Seconds 10
                Write-Verbose "Checking thread status..."
                $runResult = Invoke-MetroAIApiCall -Service 'threads' -Operation 'threadStatus' -Path ("{0}/runs/{1}" -f $response.thread_id, $response.id) -Method Get
                $i++
            } while ($terminalStatuses -notcontains $runResult.status -and $i -lt 100)

            if (-not $runResult) {
                throw "Thread run status could not be retrieved."
            }

            switch ($runResult.status) {
                'completed' {
                    $result = Invoke-MetroAIApiCall -Service 'threads' -Operation 'messages' -Path ("{0}/messages" -f $response.thread_id) -Method Get
                    return $result.data |
                        Where-Object { $_.role -eq 'assistant' } |
                        ForEach-Object {
                            $segments = Convert-MetroAIMessageContent -Message $_
                            if ($segments.Count -gt 0) {
                                $segments -join [Environment]::NewLine
                            }
                        }
                }
                'requires_action' {
                    return [pscustomobject]@{
                        Status          = 'requires_action'
                        ThreadId        = $response.thread_id
                        RunId           = $response.id
                        RequiredAction  = $runResult.required_action
                        LastError       = $runResult.last_error
                    }
                }
                'failed' {
                    $errorMessage = if ($runResult.last_error) { $runResult.last_error.message } else { "Thread run failed." }
                    throw $errorMessage
                }
                default {
                    throw "Thread run ended with status '$($runResult.status)'."
                }
            }
        }
        else {
            Write-Output "Run started asynchronously. Use Get-MetroAIThreadRunStatus to check."
        }
        return @{ ThreadID = $response.thread_id; RunID = $response.id }
    }
    catch {
        Write-Error "Start-MetroAIThreadWithMessages error: $_"
    }
}
