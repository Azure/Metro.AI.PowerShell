function Get-MetroAIContextCachePath {
    <#
    .SYNOPSIS
        Gets the path to the Metro AI context cache file.
    #>
    $profileDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        [System.Environment]::GetFolderPath('ApplicationData')
    }
    else {
        $env:HOME
    }

    $metroDir = Join-Path $profileDir '.metroai'
    if (-not (Test-Path $metroDir)) {
        $null = New-Item -ItemType Directory -Path $metroDir -Force
    }

    return Join-Path $metroDir 'context.json'
}
