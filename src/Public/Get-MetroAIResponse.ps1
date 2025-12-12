function Get-MetroAIResponse {
    <#
        .SYNOPSIS
            Retrieves responses or a specific response.
        .EXAMPLE
            Get-MetroAIResponse
        .EXAMPLE
            Get-MetroAIResponse -ResponseId "resp123"
    #>
    [CmdletBinding(DefaultParameterSetName = "List")]
    param(
        [Parameter(ParameterSetName = "GetById", Mandatory = $true)]
        [string]$ResponseId
    )
    try {
        $path = if ($PSCmdlet.ParameterSetName -eq 'GetById') { $ResponseId } else { $null }
        $result = Invoke-MetroAIApiCall -Service 'openai/responses' -Operation 'responses' -Path $path -Method Get

        if ($PSCmdlet.ParameterSetName -eq 'List') {
            if ($result.PSObject.Properties.Name -contains 'value') { return $result.value }
            if ($result.PSObject.Properties.Name -contains 'data') { return $result.data }
        }
        return $result
    }
    catch {
        Write-Error "Get-MetroAIResponse error: $_"
    }
}
