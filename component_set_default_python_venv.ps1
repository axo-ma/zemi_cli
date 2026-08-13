[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AbsolutePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$instanceMarkerNames = @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod")

function Find-ZemiProjectRoot {
    param([string]$StartPath)

    $candidate = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    while ($candidate) {
        if ((Test-Path -LiteralPath (Join-Path $candidate ".zemicomp") -PathType Leaf) -or
            (Test-Path -LiteralPath (Join-Path $candidate ".zemiworkroot") -PathType Leaf)) {
            return $candidate
        }

        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) {
            return $null
        }
        $candidate = $parent
    }
}

function Find-ZemiInstanceRoot {
    param([string]$StartPath)

    $candidate = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    while ($candidate) {
        $markers = @(
            Get-ChildItem -LiteralPath $candidate -Force -File |
                Where-Object { $_.Name -in $instanceMarkerNames }
        )
        if ($markers.Count -eq 1) {
            return $candidate
        }
        if ($markers.Count -gt 1) {
            throw "Expected exactly one ZEMI Instance marker in: $candidate"
        }

        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) {
            return $null
        }
        $candidate = $parent
    }
}

function Find-LatestDefaultPythonVenv {
    param([string]$InstanceRoot)

    $venvsRoot = Join-Path $InstanceRoot "_venvs"
    if (-not (Test-Path -LiteralPath $venvsRoot -PathType Container)) {
        return $null
    }

    $defaultVenvs = @(
        Get-ChildItem -LiteralPath $venvsRoot -Directory |
            ForEach-Object {
                if ($_.Name -match '^default-(WPy64-(\d+))$' -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName "Scripts\python.exe") -PathType Leaf) -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName "pyvenv.cfg") -PathType Leaf)) {
                    $numericVersion = 0L
                    if ([long]::TryParse($Matches[2], [ref]$numericVersion)) {
                        [pscustomobject]@{
                            Name = $_.Name
                            NumericVersion = $numericVersion
                            PythonPath = [IO.Path]::GetFullPath(
                                (Join-Path $_.FullName "Scripts\python.exe")
                            )
                        }
                    }
                }
            }
    )

    return $defaultVenvs |
        Sort-Object -Property NumericVersion, Name -Descending |
        Select-Object -First 1
}

$projectRoot = Find-ZemiProjectRoot -StartPath (Get-Location).ProviderPath
if (-not $projectRoot) {
    throw "No ZEMI project root was found above the current directory. Run this command inside a directory marked with .zemicomp or .zemiworkroot."
}

$instanceRoot = Find-ZemiInstanceRoot -StartPath (Split-Path -Parent $projectRoot)
if (-not $instanceRoot) {
    throw "No ZEMI Instance was found above the current project root: $projectRoot"
}

$defaultVenv = Find-LatestDefaultPythonVenv -InstanceRoot $instanceRoot
if (-not $defaultVenv) {
    throw @"
No default Python venv was found in this ZEMI Instance.
Create one, then run this command again:
  zemi instance setup-vscode-workspace -InstancePath "$instanceRoot"
"@
}

$vscodeRoot = Join-Path $projectRoot ".vscode"
$settingsPath = Join-Path $vscodeRoot "settings.json"
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    try {
        $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "The project VS Code settings file is not valid JSON: $settingsPath"
    }
    if ($settings -isnot [PSCustomObject]) {
        throw "The project VS Code settings file must contain a JSON object: $settingsPath"
    }
}
else {
    $settings = [PSCustomObject]@{}
}

$interpreterPath = if ($AbsolutePath) {
    $defaultVenv.PythonPath
}
else {
    '${workspaceFolder}/' + [Uri]::UnescapeDataString(
        (New-Object Uri(
            ([IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar)
        )).MakeRelativeUri((New-Object Uri($defaultVenv.PythonPath))).ToString()
    )
}

$settings |
    Add-Member `
        -MemberType NoteProperty `
        -Name "python.defaultInterpreterPath" `
        -Value $interpreterPath `
        -Force

if (-not $PSCmdlet.ShouldProcess($settingsPath, "Set the project default Python venv to $($defaultVenv.Name)")) {
    return
}

[void](New-Item -ItemType Directory -Path $vscodeRoot -Force)
$settingsJson = $settings | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText(
    $settingsPath,
    $settingsJson + [Environment]::NewLine,
    (New-Object Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "[OK] Default Python venv set for the current project." -ForegroundColor Green
Write-Host "Project:  $projectRoot"
Write-Host "Python:    $($defaultVenv.PythonPath)"
Write-Host "Path mode: $(if ($AbsolutePath) { 'absolute' } else { 'workspace-relative' })"
Write-Host "Settings:  $settingsPath"
