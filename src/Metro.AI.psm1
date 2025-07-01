#Requires -Version 7.0

# Initialize the module-level context variable
$script:MetroContext = $null

# Import Classes
$classFiles = Get-ChildItem -Path "$PSScriptRoot/Classes/*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $classFiles) {
    Write-Verbose "Loading class: $($file.BaseName)"
    . $file.FullName
}


# Import Private Functions
$allPrivateFiles = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $allPrivateFiles) {
    if ($privateFunctionOrder -notcontains $file.BaseName) {
        Write-Verbose "Loading additional private function: $($file.BaseName)"
        . $file.FullName
    }
}

# Import Public Functions
$publicFiles = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    Write-Verbose "Loading public function: $($file.BaseName)"
    . $file.FullName
}

# Module initialization - try to load cached context
$cachedContext = Get-MetroAIContextCache
if ($cachedContext) {
    $script:MetroContext = $cachedContext
    Write-Host "Metro AI context auto-loaded from cache: $($cachedContext.ApiType) API at $($cachedContext.Endpoint)" -ForegroundColor Green
}

# Export all public functions and aliases
$publicFunctionNames = $publicFiles | ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $publicFunctionNames

# Export aliases defined in the manifest
$aliasesToExport = @(
    'Get-MetroAIAgent',
    'Get-MetroAIAssistant',
    'Set-MetroAIAgent',
    'Set-MetroAIAssistant',
    'New-MetroAIAgent',
    'New-MetroAIAssistant',
    'Remove-MetroAIAgent',
    'Remove-MetroAIAssistant'
)
Export-ModuleMember -Alias $aliasesToExport
