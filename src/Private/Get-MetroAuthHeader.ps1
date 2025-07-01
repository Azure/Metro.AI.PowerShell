function Get-MetroAuthHeader {
    <#
    .SYNOPSIS
        Returns a header hashtable with an authorization token for the specified API type,
        automatically choosing the right Azure resource URL for old vs new endpoints.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Agent', 'Assistant')]
        [string]$ApiType
    )
    try {
        # make sure our context is set
        if (-not $script:MetroContext) {
            throw "No Metro AI context set. Use Set-MetroAIContext first."
        }

        # decide which resource to ask a token for
        if ($script:MetroContext.UseNewApi) {
            # unified new AI surface
            $resourceUrl = "https://ai.azure.com/"
        }
        elseif ($ApiType -eq 'Agent') {
            # old Agent endpoint
            $resourceUrl = "https://ml.azure.com/"
        }
        else {
            # old Assistant endpoint
            $resourceUrl = "https://cognitiveservices.azure.com/"
        }

        # grab the token
        $token = (Get-AzAccessToken -ResourceUrl $resourceUrl -AsSecureString).Token `
        | ConvertFrom-SecureString -AsPlainText
        if (-not $token) {
            throw "Token retrieval failed for resource $resourceUrl"
        }

        # return the bare auth header;
        # x-ms-enable-preview goes in Invoke-MetroAIApiCall so it's applied on every request uniformly
        return @{ Authorization = "Bearer $token" }
    }
    catch {
        Write-Error "Get-MetroAuthHeader error for '$ApiType': $_"
    }
}
