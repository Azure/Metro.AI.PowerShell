function Invoke-MetroAIConversation {
    <#
        .SYNOPSIS
            Sends a turn to an agent within a conversation using the Responses API.
        .EXAMPLE
            Invoke-MetroAIConversation -AgentName "my-agent" -ConversationId "abc123" -Input "Hello"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentName,

        [Parameter(Mandatory = $true)]
        [string]$ConversationId,

        # Avoid conflict with PowerShell's automatic $input variable
        [Parameter(Mandatory = $true)]
        [Alias('Input','Message','Prompt')]
        [object]$UserInput,

        [switch]$PassThru,

        [switch]$AutoApprove
    )
    try {
        if ($null -eq $UserInput) {
            throw "Input is required and cannot be empty. The Responses API needs either 'input' or 'prompt'."
        }

        # Normalize input. The Foundry Agents Responses API accepts either:
        # - a simple string (most common), or
        # - an array/object of typed input items (e.g., input_text/input_audio).
        # Avoid wrapping into message-role/content arrays, which the service rejects.
        $inputPayload = $null

        if ($UserInput -is [string]) {
            if ([string]::IsNullOrWhiteSpace($UserInput)) {
                throw "Input is required and cannot be empty. The Responses API needs either 'input' or 'prompt'."
            }
            $inputPayload = $UserInput
        }
        elseif ($UserInput -is [System.Collections.IEnumerable] -and -not ($UserInput -is [string])) {
            $inputPayload = @($UserInput)
            if ($inputPayload.Count -eq 0) {
                throw "Input is required and cannot be empty. The Responses API needs either 'input' or 'prompt'."
            }
        }
        elseif ($UserInput.PSObject.Properties.Name -contains 'type') {
            # Single typed input object (e.g., @{ type='input_text'; text='hi' })
            $inputPayload = $UserInput
        }
        else {
            # Fallback to a single string representation.
            $inputPayload = ($UserInput | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($inputPayload)) {
                throw "Input is required and cannot be empty. The Responses API needs either 'input' or 'prompt'."
            }
        }

        $currentInput = $inputPayload
        $assistantTextParts = @()
        $lastResponse = $null
        $keepGoing = $true

        while ($keepGoing) {
            $body = @{
                agent        = @{ type = 'agent_reference'; name = $AgentName }
                input        = $currentInput
            }

            if ($lastResponse -and $lastResponse.id) {
                $body['previous_response_id'] = $lastResponse.id
            }
            else {
                $body['conversation'] = $ConversationId
            }

            if ($PSBoundParameters['Verbose'] -or $VerbosePreference -ne 'SilentlyContinue') {
                try {
                    $jsonBody = $body | ConvertTo-Json -Depth 10 -Compress
                    Write-Verbose "Request Body: $jsonBody"
                } catch {
                    Write-Verbose "Request Body: (Failed to serialize for logging)"
                }
            }

            $response = Invoke-MetroAIApiCall -Service 'openai/responses' -Operation 'responses' -Method Post -ContentType "application/json" -Body $body
            $lastResponse = $response

            if (-not $response) {
                throw "No response returned from the service."
            }

            $approvalRequests = @()

            if ($response.PSObject.Properties.Name -contains "output") {
                foreach ($outputItem in $response.output) {
                    if ($outputItem.type -eq "message" -and $outputItem.role -eq "assistant") {
                        foreach ($contentPart in $outputItem.content) {
                            if ($contentPart.type -eq "output_text" -and $contentPart.text) {
                                $textValue = $null
                                if ($contentPart.text -is [string]) {
                                    $textValue = $contentPart.text
                                }
                                elseif ($contentPart.text.PSObject.Properties.Name -contains "value") {
                                    $textValue = $contentPart.text.value
                                }
                                if ($textValue) {
                                    $assistantTextParts += $textValue
                                }
                            }
                        }
                    }
                    elseif ($outputItem.type -eq "mcp_approval_request") {
                        $approvalRequests += $outputItem
                    }
                }
            }

            if ($approvalRequests.Count -gt 0) {
                # Use a generic list to ensure ConvertTo-Json serializes as an array, even with a single item.
                $nextInputItems = [System.Collections.Generic.List[object]]::new()
                foreach ($req in $approvalRequests) {
                    Write-Host "MCP Approval Request:" -ForegroundColor Yellow
                    Write-Host "  Server: $($req.server_label)" -ForegroundColor Cyan
                    Write-Host "  Tool:   $($req.name)" -ForegroundColor Cyan
                    Write-Host "  Args:   $($req.arguments)" -ForegroundColor Cyan
                    Write-Verbose "  Request ID: $($req.id)"
                    
                    $isApproved = $false
                    if ($AutoApprove) {
                        Write-Host "Auto-approving action due to -AutoApprove switch." -ForegroundColor Green
                        $isApproved = $true
                    }
                    else {
                        $userChoice = Read-Host "Do you approve this action? (y/n)"
                        $isApproved = $userChoice -eq 'y'
                    }
                    
                    $nextInputItems.Add(@{
                        type = 'mcp_approval_response'
                        approval_request_id = $req.id
                        approve = $isApproved
                    })
                }
                $currentInput = $nextInputItems
            }
            else {
                $keepGoing = $false
            }
        }

        $assistantText = ($assistantTextParts -join "`n")

        [PSCustomObject]@{
            AssistantText  = $assistantText
            ResponseId     = $lastResponse.id
            ConversationId = $ConversationId
            RawResponse    = $(if ($PassThru) { $lastResponse } else { $null })
        }
    }
    catch {
        Write-Error "Invoke-MetroAIConversation error: $_"
    }
}
