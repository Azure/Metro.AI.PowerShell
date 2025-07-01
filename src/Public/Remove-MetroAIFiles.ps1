function Remove-MetroAIFiles {
    <#
    .SYNOPSIS
        Deletes files from an endpoint.
    .DESCRIPTION
        Removes the specified file (or all files if FileId is not provided).
    .PARAMETER FileId
        Optional specific file ID.
    #>
    [CmdletBinding()]
    param (
        [string]$FileId
    )
    try {
        $files = Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Method Get
        if ($FileId) {
            $item = $files.data | Where-Object { $_.id -eq $FileId }
            if ($item) {
                Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Path $FileId -Method Delete
                Write-Output "File $FileId deleted."
            }
            else { Write-Error "File $FileId not found." }
        }
        else {
            foreach ($file in $files.data) {
                try {
                    Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Path $file.id -Method Delete
                }
                catch { Write-Error "Error deleting file $($file.id): $_" }
            }
        }
    }
    catch {
        Write-Error "Remove-MetroAIFiles error: $_"
    }
}
