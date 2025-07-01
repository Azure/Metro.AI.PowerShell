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
