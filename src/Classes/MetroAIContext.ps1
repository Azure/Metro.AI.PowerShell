class MetroAIContext {
    [string]$Endpoint
    [ValidateSet('Agent', 'Assistant')]
    [string]$ApiType

    [bool]$UseNewApi
    [string]$ApiVersion

    MetroAIContext([string]$endpoint, [string]$apiType, [string]$apiVersion = "") {
        # keep your original logic for simple endpoint+apiType
        $this.Endpoint = $endpoint.TrimEnd('/')
        $this.ApiType = $apiType
        $this.ApiVersion = $apiVersion

        # auto-detect new vs old based on hostname
        # new AI endpoints live under *.ai.azure.com
        $this.UseNewApi = $this.Endpoint -match '\.ai\.azure\.com'
    }

    MetroAIContext([string]$connectionString, [string]$apiType, [switch]$fromConnectionString) {
        # exactly your original split/format
        $parts = $connectionString -split ';'
        if ($parts.Count -ne 4) { throw "Invalid connection string format." }
        $this.Endpoint = ('https://{0}/agents/v1.0/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.MachineLearningServices/workspaces/{3}' -f $parts)
        $this.ApiType = $apiType
        $this.ApiVersion = ""
    }

    [string] ResolveUri(
        [string]$Service,
        [string]$Operation,
        [string]$Path = "",
        [switch]$UseOpenPrefix
    ) {
        if ($this.UseNewApi) {
            # new surface: endpoint already includes /api/projects/{…}
            $base = "$($this.Endpoint)/$Service"
            if ($Path) { $base += "/$Path" }
            $ver = if ($this.ApiVersion) { $this.ApiVersion } else { '2025-05-15-preview' }
            return "$base`?api-version=$ver"
        }

        # old-style behavior
        $prefix = ($this.ApiType -eq 'Assistant' -and $UseOpenPrefix) ? "openai/" : ""
        $baseUri = "$($this.Endpoint)/$prefix$Service"
        if ($Path) { $baseUri += "/$Path" }
        $ver = if ($this.ApiVersion) { $this.ApiVersion } else { Get-MetroApiVersion -Operation $Operation -ApiType $this.ApiType }
        return "$baseUri`?api-version=$ver"
    }
}
