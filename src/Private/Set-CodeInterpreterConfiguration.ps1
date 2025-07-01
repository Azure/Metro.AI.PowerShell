function Set-CodeInterpreterConfiguration {
    <#
    .SYNOPSIS
        Helper function to configure Code Interpreter tool and resources for Set-MetroAIResource.
    .PARAMETER RequestBody
        The request body hashtable to modify.
    .PARAMETER ExistingFileIds
        Array of existing file IDs from the current resource.
    .PARAMETER NewFileIds
        Array of new file IDs to add.
    .PARAMETER EnableCodeInterpreter
        Whether to enable the Code Interpreter tool.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RequestBody,

        [string[]]$ExistingFileIds = @(),

        [string[]]$NewFileIds = @(),

        [switch]$EnableCodeInterpreter
    )

    # Ensure tool_resources exists as hashtable
    if (-not $RequestBody.tool_resources) {
        if ($RequestBody -is [hashtable]) {
            $RequestBody.tool_resources = @{}
        }
        else {
            $RequestBody | Add-Member -MemberType NoteProperty -Name "tool_resources" -Value @{} -Force
        }
    }

    # Handle file IDs merging
    if ($NewFileIds -and $NewFileIds.Count -gt 0) {
        # Merge existing file IDs with new ones, removing duplicates
        $allFileIds = @($ExistingFileIds) + @($NewFileIds) | Select-Object -Unique
        # Use ArrayList to ensure proper JSON serialization as array
        $fileIdsList = [System.Collections.ArrayList]::new()
        foreach ($fileId in $allFileIds) {
            $null = $fileIdsList.Add($fileId)
        }
        $codeInterpreterConfig = @{ file_ids = $fileIdsList.ToArray() }

        if ($RequestBody.tool_resources -is [hashtable]) {
            $RequestBody.tool_resources.code_interpreter = $codeInterpreterConfig
        }
        else {
            $RequestBody.tool_resources | Add-Member -MemberType NoteProperty -Name "code_interpreter" -Value $codeInterpreterConfig -Force
        }
        Write-Verbose "Merged existing file IDs with new ones: $($fileIdsList.Count) total files"
    }
    elseif ($ExistingFileIds.Count -gt 0) {
        # Keep existing file IDs if no new ones provided
        # Use ArrayList to ensure proper JSON serialization as array
        $fileIdsList = [System.Collections.ArrayList]::new()
        foreach ($fileId in $ExistingFileIds) {
            $null = $fileIdsList.Add($fileId)
        }
        $codeInterpreterConfig = @{ file_ids = $fileIdsList.ToArray() }

        if ($RequestBody.tool_resources -is [hashtable]) {
            $RequestBody.tool_resources.code_interpreter = $codeInterpreterConfig
        }
        else {
            $RequestBody.tool_resources | Add-Member -MemberType NoteProperty -Name "code_interpreter" -Value $codeInterpreterConfig -Force
        }
        Write-Verbose "Preserved existing file IDs: $($ExistingFileIds.Count) files"
    }
    else {
        # No files, create empty file_ids array
        $codeInterpreterConfig = @{ file_ids = @() }

        if ($RequestBody.tool_resources -is [hashtable]) {
            $RequestBody.tool_resources.code_interpreter = $codeInterpreterConfig
        }
        else {
            $RequestBody.tool_resources | Add-Member -MemberType NoteProperty -Name "code_interpreter" -Value $codeInterpreterConfig -Force
        }
        Write-Verbose "Created empty file_ids array for code interpreter"
    }

    # Add code_interpreter tool if EnableCodeInterpreter is specified and not already present
    if ($EnableCodeInterpreter -and $RequestBody.tools) {
        $currentToolTypes = $RequestBody.tools | ForEach-Object { $_.type }

        if ($currentToolTypes -notcontains "code_interpreter") {
            $newToolsList = [System.Collections.Generic.List[object]]::new()
            foreach ($tool in $RequestBody.tools) {
                $newToolsList.Add($tool)
            }
            $newToolsList.Add(@{ type = "code_interpreter" })
            $RequestBody.tools = $newToolsList.ToArray()
            Write-Verbose "Added code_interpreter tool"
        }
    }
}
