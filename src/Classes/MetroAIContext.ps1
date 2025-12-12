class MetroAIContext {
    [string]$Endpoint
    [ValidateSet('Agent', 'Assistant')]
    [string]$ApiType

    [bool]$CurrentApi
    [string]$ApiVersion

    MetroAIContext([string]$endpoint, [string]$apiType, [string]$apiVersion = "") {
        # Foundry preview Agents API lives under *.ai.azure.com project endpoints
        $this.Endpoint = $endpoint.TrimEnd('/')
        $this.ApiType = $apiType
        $this.ApiVersion = $apiVersion

        # Only the new API is supported now
        $this.CurrentApi = $this.Endpoint -match '\.ai\.azure\.com'
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
        if (-not $this.CurrentApi) {
            throw "Legacy Assistant/V1 endpoints are no longer supported. Please use a Foundry project endpoint under *.ai.azure.com."
        }

        # Endpoint already includes /api/projects/{projectId}
        $base = "$($this.Endpoint)/$Service"
        if ($Path) { $base += "/$Path" }
        $ver = if ($this.ApiVersion) { $this.ApiVersion } else { '2025-11-15-preview' }
        return "$base`?api-version=$ver"
    }
}
