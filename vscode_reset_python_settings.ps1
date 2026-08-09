[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$codePaths = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match '^Code($| -)' } |
        ForEach-Object { $_.Path } |
        Where-Object { $_ } |
        Sort-Object -Unique
)
if ($codePaths.Count -eq 0) {
    Write-Host "[ERROR] Start VS Code and run this command again." -ForegroundColor Red
    exit 1
}
if ($codePaths.Count -gt 1) {
    Write-Host "[ERROR] More than one VS Code installation is running. Keep only one open." -ForegroundColor Red
    exit 1
}

$codeRoot = Split-Path -Parent $codePaths[0]
$portableUserRoot = Join-Path $codeRoot "data\user-data\User"
$userRoot = if (Test-Path -LiteralPath $portableUserRoot -PathType Container) {
    $portableUserRoot
}
else {
    Join-Path $env:APPDATA "Code\User"
}
$settingsPath = Join-Path $userRoot "settings.json"

if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    Write-Host "[OK] VS Code has no Python or Jupyter settings to reset." -ForegroundColor Green
    return
}

$settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$removed = 0

foreach ($property in @($settings.PSObject.Properties)) {
    if ($property.Name -match '^(python|python-envs|jupyter)\.') {
        $settings.PSObject.Properties.Remove($property.Name)
        $removed++
    }
}

$terminalEnvironment = $settings.'terminal.integrated.env.windows'
if ($terminalEnvironment) {
    foreach ($name in @("PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV", "CONDA_PREFIX")) {
        $property = $terminalEnvironment.PSObject.Properties[$name]
        if ($property) {
            $terminalEnvironment.PSObject.Properties.Remove($property.Name)
            $removed++
        }
    }

    $pathProperty = $terminalEnvironment.PSObject.Properties["PATH"]
    if ($pathProperty -and $pathProperty.Value) {
        $oldPath = [string]$pathProperty.Value
        $newPath = @(
            $oldPath -split ';' |
                Where-Object {
                    $_ -notmatch '(?i)(\\\.venv(\\|$)|\\_pythons(\\|$)|\\WPy64-|\\python(\\|$)|\\conda(\\|$))'
                }
        ) -join ';'
        if ($newPath -ne $oldPath) {
            $pathProperty.Value = $newPath
            $removed++
        }
    }
}

if ($removed -gt 0) {
    $json = $settings | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText(
        $settingsPath,
        $json + [Environment]::NewLine,
        (New-Object Text.UTF8Encoding($false))
    )
}

Write-Host "[OK] Python and Jupyter settings reset: $removed" -ForegroundColor Green
Write-Host "Restart VS Code. It will discover the project .venv automatically."
