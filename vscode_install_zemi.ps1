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
    Write-Host "[ERROR] Start portable VS Code and run this script again." -ForegroundColor Red
    exit 1
}
if ($codePaths.Count -gt 1) {
    Write-Host "[ERROR] More than one VS Code installation is running. Keep only one open." -ForegroundColor Red
    exit 1
}

$codeRoot = Split-Path -Parent $codePaths[0]
$portableUserRoot = Join-Path $codeRoot "data\user-data\User"
if (Test-Path -LiteralPath $portableUserRoot -PathType Container) {
    $userRoot = $portableUserRoot
}
else {
    $userRoot = Join-Path $env:APPDATA "Code\User"
}
if (-not (Test-Path -LiteralPath $userRoot -PathType Container)) {
    throw "VS Code User directory was not found: $userRoot"
}

$cliRoot = (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath
$settingsPath = Join-Path $userRoot "settings.json"
$extensionPath = Join-Path $cliRoot "vscode-zemi-python-env\dist\zemi-python-environment-0.1.1.vsix"
if (-not (Test-Path -LiteralPath $extensionPath -PathType Leaf)) {
    throw "ZEMI VS Code extension was not found: $extensionPath"
}

if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
}
else {
    $settings = [PSCustomObject]@{}
}

$terminalEnvironment = $settings.'terminal.integrated.env.windows'
if (-not $terminalEnvironment) {
    $terminalEnvironment = [PSCustomObject]@{}
}

$currentPath = [string]$terminalEnvironment.PATH
$cliAlreadyPresent = @(
    $currentPath -split ';' |
        Where-Object { $_.Trim().TrimEnd('\') -ieq $cliRoot.TrimEnd('\') }
).Count -gt 0

if (-not $cliAlreadyPresent) {
    if ([string]::IsNullOrWhiteSpace($currentPath)) {
        $currentPath = '$' + '{env:PATH}'
    }

    $terminalEnvironment |
        Add-Member -MemberType NoteProperty -Name "PATH" -Value "$cliRoot;$currentPath" -Force
    $settings |
        Add-Member -MemberType NoteProperty -Name "terminal.integrated.env.windows" -Value $terminalEnvironment -Force

    $json = $settings | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText(
        $settingsPath,
        $json + [Environment]::NewLine,
        (New-Object Text.UTF8Encoding($false))
    )
}

& $codePaths[0] --install-extension $extensionPath --force
if ($LASTEXITCODE -ne 0) {
    throw "VS Code failed to install the ZEMI Python Environment extension."
}

Write-Host "[OK] ZEMI is installed in VS Code." -ForegroundColor Green
Write-Host "CLI:      $cliRoot"
Write-Host "Extension: $extensionPath"
Write-Host "Settings: $settingsPath"
Write-Host "Windows PATH was not changed."
