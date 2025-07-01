function Invoke-MetroAIUploadFile {
    <#
    .SYNOPSIS
        Uploads a file to the API endpoint.
    .DESCRIPTION
        Reads a local file and uploads it via a multipart/form-data request.
    .PARAMETER FilePath
        The local path to the file.
    .PARAMETER Purpose
        The purpose of the file upload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string]$Purpose = "assistants"
    )
    try {
        $fileItem = Get-Item -Path $FilePath -ErrorAction Stop
        $body = @{ purpose = $Purpose; file = $fileItem }
        Invoke-MetroAIApiCall -Service 'files' -Operation 'upload' -Method Post -Form $body -ContentType "multipart/form-data"
    }
    catch {
        Write-Error "Invoke-MetroAIUploadFile error: $_"
    }
}
