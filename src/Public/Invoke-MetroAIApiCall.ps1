function Invoke-MetroAIApiCall {
    <#
    .SYNOPSIS
        Generalized API caller for Metro AI endpoints.
    .DESCRIPTION
        Constructs the full API URI, obtains the authorization header, merges additional headers,
        and invokes the REST method with error handling.
    .PARAMETER Service
        The service segment.
    .PARAMETER Operation
        The operation name used to determine the API version.
    .PARAMETER Path
        Optional additional path appended to the URI.
    .PARAMETER Method
        The HTTP method (e.g. Get, Post, Delete). Defaults to "Get".
    .PARAMETER Body
        Optional body content for POST/PUT requests.
    .PARAMETER ContentType
        Optional content type (e.g. "application/json").
    .PARAMETER AdditionalHeaders
        Optional extra headers to merge with the authorization header.
    .PARAMETER TimeoutSeconds
        Optional REST call timeout (default 100 seconds).
    .PARAMETER UseOpenPrefix
        Switch to use the "openai/" prefix for Assistant API calls.
    .PARAMETER Form
        Optional parameter for multipart/form-data form data.
    .EXAMPLE
        Invoke-MetroAIApiCall -Endpoint "https://aoai-policyassistant.openai.azure.com" -ApiType Assistant `
            -Service 'threads' -Operation 'thread' -Method Post -ContentType "application/json" `
            -Body @{ some = "data" } -UseOpenPrefix
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Service,
        [Parameter(Mandatory = $true)] [string]$Operation,
        [Parameter(Mandatory = $false)] [string]$Path,
        [Parameter(Mandatory = $false)] [string]$Method = "Get",
        [Parameter(Mandatory = $false)] [object]$Body,
        [Parameter(Mandatory = $false)] [string]$ContentType,
        [Parameter(Mandatory = $false)] [hashtable]$AdditionalHeaders,
        [Parameter(Mandatory = $false)] [int]$TimeoutSeconds = 100,
        [Parameter(Mandatory = $false)] [switch]$UseOpenPrefix,
        [Parameter(Mandatory = $false)] [object]$Form
    )
    if (-not $script:MetroContext) {
        throw "MetroAI context not set. Use Set-MetroAIContext before invoking calls."
    }
    try {
        $authHeader = Get-MetroAuthHeader -ApiType $script:MetroContext.ApiType
        if ($AdditionalHeaders) { $authHeader += $AdditionalHeaders }

        $uri = $script:MetroContext.ResolveUri($Service, $Operation, $Path, $UseOpenPrefix)

        Write-Verbose "Calling API at URI: $uri with method $Method"

        $invokeParams = @{
            Uri        = $uri
            Method     = $Method
            Headers    = $authHeader
            TimeoutSec = $TimeoutSeconds
        }
        if ($ContentType) { $invokeParams.ContentType = $ContentType }
        if ($Form) {
            $invokeParams.Form = $Form
        }
        elseif ($Body) {
            if ($ContentType -eq "application/json") {
                $invokeParams.Body = $Body | ConvertTo-Json -Depth 100
            }
            else {
                $invokeParams.Body = $Body
            }
        }
        return Invoke-RestMethod @invokeParams
    }
    catch {
        Write-Error "Invoke-MetroAIApiCall error: $_"
    }
}
