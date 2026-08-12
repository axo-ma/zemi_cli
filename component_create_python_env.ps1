[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$instanceMarkerNames = @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod")
$winPythonFolderName = "WPy64-312101"

function Find-ZemiComponentRoot {
    param([string]$StartPath)

    $currentPath = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    while ($currentPath) {
        if (Test-Path -LiteralPath (Join-Path $currentPath ".zemicomp") -PathType Leaf) {
            return $currentPath
        }

        $parentPath = Split-Path -Parent $currentPath
        if (-not $parentPath -or $parentPath -eq $currentPath) {
            break
        }
        $currentPath = $parentPath
    }

    throw "Run this command from a ZEMI Component containing a .zemicomp marker."
}

function Find-ZemiInstanceRoot {
    param([string]$StartPath)

    $currentPath = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    while ($currentPath) {
        $markers = @(
            Get-ChildItem -LiteralPath $currentPath -Force -File |
                Where-Object { $_.Name -in $instanceMarkerNames }
        )

        if ($markers.Count -gt 0) {
            if ($markers.Count -ne 1) {
                throw "Expected exactly one ZEMI Instance marker in: $currentPath"
            }
            return $currentPath
        }

        $parentPath = Split-Path -Parent $currentPath
        if (-not $parentPath -or $parentPath -eq $currentPath) {
            break
        }
        $currentPath = $parentPath
    }

    throw "ZEMI Instance was not found above the component directory."
}

function Get-PythonEnvHome {
    param([string]$PythonEnvRoot)

    $configurationPath = Join-Path $PythonEnvRoot "pyvenv.cfg"
    if (-not (Test-Path -LiteralPath $configurationPath -PathType Leaf)) {
        return $null
    }

    $configuration = Get-Content -LiteralPath $configurationPath -Raw -Encoding UTF8
    $homeMatch = [regex]::Match($configuration, "(?m)^home\s*=\s*(.+?)\s*$")
    if (-not $homeMatch.Success) {
        return $null
    }

    return $homeMatch.Groups[1].Value.Trim().Trim('"')
}

function Test-PythonEnvUsesSystemSitePackages {
    param([string]$PythonEnvRoot)

    $configurationPath = Join-Path $PythonEnvRoot "pyvenv.cfg"
    if (-not (Test-Path -LiteralPath $configurationPath -PathType Leaf)) {
        return $false
    }

    $configuration = Get-Content -LiteralPath $configurationPath -Raw -Encoding UTF8
    return $configuration -match "(?m)^include-system-site-packages\s*=\s*true\s*$"
}

function Test-SamePath {
    param(
        [string]$FirstPath,
        [string]$SecondPath
    )

    if ([string]::IsNullOrWhiteSpace($FirstPath) -or [string]::IsNullOrWhiteSpace($SecondPath)) {
        return $false
    }

    $firstFullPath = [IO.Path]::GetFullPath($FirstPath).TrimEnd('\')
    $secondFullPath = [IO.Path]::GetFullPath($SecondPath).TrimEnd('\')
    return $firstFullPath.Equals($secondFullPath, [StringComparison]::OrdinalIgnoreCase)
}

$componentRoot = Find-ZemiComponentRoot -StartPath (Get-Location).ProviderPath
$instanceSearchRoot = Split-Path -Parent $componentRoot
$instanceRoot = Find-ZemiInstanceRoot -StartPath $instanceSearchRoot

$winPythonRoot = Join-Path $instanceRoot "_pythons\$winPythonFolderName\python"
$winPythonExecutable = Join-Path $winPythonRoot "python.exe"
if (-not (Test-Path -LiteralPath $winPythonExecutable -PathType Leaf)) {
    throw "WinPython was not found: $winPythonExecutable`nRun 'zemi instance download-winpython' and extract it before creating the Python environment."
}

$pythonEnvRoot = Join-Path $componentRoot ".venv"
$pythonEnvExecutable = Join-Path $pythonEnvRoot "Scripts\python.exe"

if (Test-Path -LiteralPath $pythonEnvRoot) {
    $existingHome = Get-PythonEnvHome -PythonEnvRoot $pythonEnvRoot
    if (
        (Test-Path -LiteralPath $pythonEnvRoot -PathType Container) -and
        (Test-Path -LiteralPath $pythonEnvExecutable -PathType Leaf) -and
        (Test-SamePath -FirstPath $existingHome -SecondPath $winPythonRoot) -and
        (Test-PythonEnvUsesSystemSitePackages -PythonEnvRoot $pythonEnvRoot)
    ) {
        Write-Host "[OK] The component Python environment already uses the expected WinPython." -ForegroundColor Green
        Write-Host "Environment: $pythonEnvRoot"
        Write-Host "Base Python: $winPythonExecutable"
        return
    }

    throw "The .venv path already exists but does not use the expected WinPython with system site-packages; refusing to modify it: $pythonEnvRoot"
}

Write-Host ""
Write-Host "Python environment will be created for the ZEMI Component:"
Write-Host "  $componentRoot" -ForegroundColor Cyan
Write-Host "Base WinPython:"
Write-Host "  $winPythonExecutable" -ForegroundColor Cyan
Write-Host "Environment:"
Write-Host "  $pythonEnvRoot" -ForegroundColor Cyan
Write-Host ""

if (-not $Yes) {
    $answer = (Read-Host "Create the component Python environment? [Y/n]").Trim()
    if ($answer -and $answer -notin @("y", "yes")) {
        Write-Host "Cancelled."
        return
    }
}

if (-not $PSCmdlet.ShouldProcess($pythonEnvRoot, "Create Python environment from WinPython")) {
    return
}

& $winPythonExecutable -m venv --system-site-packages $pythonEnvRoot
if ($LASTEXITCODE -ne 0) {
    throw "Python environment creation failed. A partial directory may remain at: $pythonEnvRoot"
}

$pythonEnvGitIgnore = Join-Path $pythonEnvRoot ".gitignore"
[IO.File]::WriteAllText(
    $pythonEnvGitIgnore,
    "*" + [Environment]::NewLine,
    (New-Object Text.UTF8Encoding($false))
)

$createdHome = Get-PythonEnvHome -PythonEnvRoot $pythonEnvRoot
if (
    -not (Test-Path -LiteralPath $pythonEnvExecutable -PathType Leaf) -or
    -not (Test-SamePath -FirstPath $createdHome -SecondPath $winPythonRoot) -or
    -not (Test-PythonEnvUsesSystemSitePackages -PythonEnvRoot $pythonEnvRoot)
) {
    throw "Python environment verification failed: $pythonEnvRoot"
}

$reportedBasePrefix = @(& $pythonEnvExecutable -c "import sys; print(sys.base_prefix)" 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "The new Python environment could not start: $pythonEnvExecutable"
}
$basePrefix = [string]($reportedBasePrefix | Select-Object -Last 1)
if (-not (Test-SamePath -FirstPath $basePrefix.Trim() -SecondPath $winPythonRoot)) {
    throw "The new Python environment does not point to the expected WinPython: $pythonEnvRoot"
}

Write-Host ""
Write-Host "[OK] Component Python environment created." -ForegroundColor Green
Write-Host "Environment: $pythonEnvRoot"
Write-Host "Python:      $pythonEnvExecutable"
Write-Host "Base:        $winPythonRoot"
Write-Host "Packages:    includes WinPython site-packages"
