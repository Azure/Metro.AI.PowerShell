function Save-MetroAIContextCache {
    <#
    .SYNOPSIS
        Saves the current Metro AI context to cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [MetroAIContext]$Context
    )

    try {
        $cachePath = Get-MetroAIContextCachePath
        $cacheData = @{
            Endpoint   = $Context.Endpoint
            ApiType    = $Context.ApiType
            ApiVersion = $Context.ApiVersion
            UseNewApi  = $Context.UseNewApi
            CachedAt   = (Get-Date).ToString('o')
        }

        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cachePath -Encoding UTF8 -Force
        Write-Verbose "Metro AI context cached to: $cachePath"
    }
    catch {
        Write-Verbose "Failed to cache Metro AI context: $($_.Exception.Message)"
    }
}
