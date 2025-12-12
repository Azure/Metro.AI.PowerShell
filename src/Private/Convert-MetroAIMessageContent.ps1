function Convert-MetroAIMessageContent {
    <#
    .SYNOPSIS
        Normalizes assistant message content into readable text segments.
    .DESCRIPTION
        Extracts text values from assistant message content arrays while providing readable placeholders
        for non-text content such as file references or tool calls.
    .PARAMETER Message
        The message object returned by the Assistants API.
    .OUTPUTS
        Array of strings containing the readable content segments.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Message
    )

    $segments = @()

    if (-not $Message.content) {
        return $segments
    }

    foreach ($part in $Message.content) {
        switch ($part.type) {
            'text' {
                if ($part.text) {
                    if ($part.text.value) {
                        $segments += $part.text.value
                    }
                    elseif ($part.text -is [string]) {
                        $segments += $part.text
                    }
                    else {
                        $segments += ($part.text | ConvertTo-Json -Depth 5)
                    }
                }
            }
            'tool_call' {
                $toolCall = $part.tool_call
                if ($toolCall) {
                    $descriptor = if ($toolCall.function -and $toolCall.function.name) {
                        $toolCall.function.name
                    }
                    elseif ($toolCall.type) {
                        $toolCall.type
                    }
                    else {
                        'tool_call'
                    }
                    $segments += "[tool_call:$descriptor]"
                }
            }
            'file_path' {
                if ($part.file_path -and $part.file_path.file_id) {
                    $segments += "[file_path:$($part.file_path.file_id)]"
                }
            }
            'image_file' {
                if ($part.image_file -and $part.image_file.file_id) {
                    $segments += "[image_file:$($part.image_file.file_id)]"
                }
            }
            default {
                try {
                    $segments += "[$($part.type)] $($part | ConvertTo-Json -Depth 3)"
                }
                catch {
                    $segments += "[$($part.type)]"
                }
            }
        }
    }

    return $segments
}
