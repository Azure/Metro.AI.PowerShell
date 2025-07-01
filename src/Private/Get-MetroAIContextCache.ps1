function Get-MetroAIContextCache {
    <#
    .SYNOPSIS
        Loads Metro AI context from cache if available.
    #>
    [CmdletBinding()]
    param()

    try {
        $cachePath = Get-MetroAIContextCachePath
        if (-not (Test-Path $cachePath)) {
            Write-Verbose "No Metro AI context cache found at: $cachePath"
            return $null
        }

        $cacheData = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Validate cache data has required properties
        if (-not ($cacheData.Endpoint -and $cacheData.ApiType)) {
            Write-Verbose "Invalid Metro AI context cache data"
            return $null
        }

        # Create context from cached data
        $context = [MetroAIContext]::new($cacheData.Endpoint, $cacheData.ApiType, $cacheData.ApiVersion)

        Write-Verbose "Loaded Metro AI context from cache: $($cacheData.ApiType) API at $($cacheData.Endpoint)"
        return $context
    }
    catch {
        Write-Verbose "Failed to load Metro AI context cache: $($_.Exception.Message)"
        return $null
    }
}
