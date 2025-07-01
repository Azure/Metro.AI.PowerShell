function Clear-MetroAIContextCache {
    <#
    .SYNOPSIS
        Clears the Metro AI context cache.
    #>
    [CmdletBinding()]
    param()

    try {
        $cachePath = Get-MetroAIContextCachePath
        if (Test-Path $cachePath) {
            Remove-Item -Path $cachePath -Force
            Write-Information "Metro AI context cache cleared" -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Failed to clear Metro AI context cache: $($_.Exception.Message)"
    }
}
