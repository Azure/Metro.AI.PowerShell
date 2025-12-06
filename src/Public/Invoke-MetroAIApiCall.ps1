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
        [Parameter(Mandatory = $true, ParameterSetName = "Construct")] [string]$Service,
        [Parameter(Mandatory = $true, ParameterSetName = "Construct")] [string]$Operation,
        [Parameter(Mandatory = $false, ParameterSetName = "Construct")] [string]$Path,
        [Parameter(Mandatory = $true, ParameterSetName = "Direct")] [string]$FullUri,
        [Parameter(Mandatory = $false)] [string]$Method = "Get",
        [Parameter(Mandatory = $false)] [object]$Body,
        [Parameter(Mandatory = $false)] [string]$ContentType,
        [Parameter(Mandatory = $false)] [hashtable]$AdditionalHeaders,
        [Parameter(Mandatory = $false)] [int]$TimeoutSeconds = 100,
        [Parameter(Mandatory = $false)] [switch]$UseOpenPrefix,
        [Parameter(Mandatory = $false)] [object]$Form,
        [Parameter(Mandatory = $false)] [int[]]$SuppressErrorCodes = @()
    )
    if (-not $script:MetroContext) {
        throw "MetroAI context not set. Use Set-MetroAIContext before invoking calls."
    }
    try {
        # Always request preview behaviors so the Foundry Agents endpoints work consistently.
        $headers = Get-MetroAuthHeader -ApiType $script:MetroContext.ApiType
        $headers["x-ms-enable-preview"] = "true"
        if ($AdditionalHeaders) {
            foreach ($key in $AdditionalHeaders.Keys) {
                $headers[$key] = $AdditionalHeaders[$key]
            }
        }

        $uri = $null
        if ($PSCmdlet.ParameterSetName -eq "Direct") {
            $uri = $FullUri
        } else {
            $uri = $script:MetroContext.ResolveUri($Service, $Operation, $Path, $UseOpenPrefix)
        }

        Write-Verbose "Calling API at URI: $uri with method $Method"

        $invokeParams = @{
            Uri        = $uri
            Method     = $Method
            Headers    = $headers
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
        $err = $_
        $resp = $err.Exception.Response
        $statusCode = $null
        $statusDescription = $null
        $requestId = $null
        $responseBody = $null

        if ($resp) {
            try { $statusCode = $resp.StatusCode.value__ } catch {}
            try { $statusDescription = $resp.StatusDescription } catch {}
            try { $requestId = $resp.Headers["x-ms-request-id"] -join ',' } catch {}
            try {
                $stream = $resp.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            }
            catch { }
        }

        $message = "Invoke-MetroAIApiCall error: $($err.Exception.Message)"
        if ($statusCode) { $message += " (HTTP $statusCode $statusDescription)" }
        if ($requestId) { $message += " RequestId: $requestId" }
        if ($responseBody) { $message += " Body: $responseBody" }

        if (-not ($statusCode -and $SuppressErrorCodes -contains $statusCode)) {
            Write-Error $message
        }
        throw
    }
}
