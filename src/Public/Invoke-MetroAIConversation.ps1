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

        [switch]$PassThru
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

        $body = @{
            agent        = @{ type = 'agent_reference'; name = $AgentName }
            conversation = $ConversationId
            input        = $inputPayload
        }

        $response = Invoke-MetroAIApiCall -Service 'openai/responses' -Operation 'responses' -Method Post -ContentType "application/json" -Body $body

        # Extract assistant text similar to prior helper shape
        $assistantTextParts = @()
        if ($response -and $response.PSObject.Properties.Name -contains "output") {
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
            }
        }

        if (-not $response) {
            throw "No response returned from the service."
        }

        $assistantText = ($assistantTextParts -join "`n")

        [PSCustomObject]@{
            AssistantText  = $assistantText
            ResponseId     = $response.id
            ConversationId = $ConversationId
            RawResponse    = $(if ($PassThru) { $response } else { $null })
        }
    }
    catch {
        Write-Error "Invoke-MetroAIConversation error: $_"
    }
}
