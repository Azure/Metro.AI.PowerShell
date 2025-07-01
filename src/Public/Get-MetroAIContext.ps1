function Get-MetroAIContext {
    if ($script:MetroContext) {
        return $script:MetroContext
    }
    else {
        # Try to load from cache
        Write-Verbose "No Metro AI context found in memory, attempting to load from cache"
        $cachedContext = Get-MetroAIContextCache

        if ($cachedContext) {
            $script:MetroContext = $cachedContext
            Write-Information "Loaded Metro AI context from cache: $($cachedContext.ApiType) API at $($cachedContext.Endpoint)" -InformationAction Continue
            return $script:MetroContext
        }
        else {
            Write-Error "No Metro AI context set. Use Set-MetroAIContext to set it."
        }
    }
}
