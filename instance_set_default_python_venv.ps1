[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstancePath,
    [string]$WinPythonName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$instanceMarkerNames = @(".zemiinst_dev", ".zemiinst_exp", ".zemiinst_prod")

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

if ([string]::IsNullOrWhiteSpace($InstancePath)) {
    $instanceRoot = Find-ZemiInstanceRoot -StartPath (Get-Location).ProviderPath
    if (-not $instanceRoot) {
        throw "No ZEMI Instance was found above the current directory. Use -InstancePath."
    }
}
else {
    if (-not (Test-Path -LiteralPath $InstancePath -PathType Container)) {
        throw "ZEMI Instance directory was not found: $InstancePath"
    }
    $instanceRoot = (Resolve-Path -LiteralPath $InstancePath).ProviderPath
    $markers = @(
        Get-ChildItem -LiteralPath $instanceRoot -Force -File |
            Where-Object { $_.Name -in $instanceMarkerNames }
    )
    if ($markers.Count -ne 1) {
        throw "Expected exactly one ZEMI Instance marker in: $instanceRoot"
    }
}

if ($PSBoundParameters.ContainsKey("WinPythonName") -and
    ([string]::IsNullOrWhiteSpace($WinPythonName) -or
    $WinPythonName -in @(".", "..") -or
    [IO.Path]::IsPathRooted($WinPythonName) -or
    $WinPythonName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0)) {
    throw "WinPythonName must be a single valid folder name."
}

$pythonsRoot = Join-Path $instanceRoot "_pythons"
$venvsRoot = Join-Path $instanceRoot "_venvs"
if (-not (Test-Path -LiteralPath $pythonsRoot -PathType Container)) {
    throw "Required ZEMI Instance directory was not found: $pythonsRoot"
}
if (Test-Path -LiteralPath $venvsRoot -PathType Leaf) {
    throw "The ZEMI Instance venv path exists and is not a directory: $venvsRoot"
}

if (-not $PSBoundParameters.ContainsKey("WinPythonName")) {
    # WinPython encodes its version in the numeric suffix of the folder name
    # (for example, WPy64-312101). ZEMI treats that suffix as an ordered version:
    # the largest number is the newest installed WinPython. A matching folder is
    # considered installed only when its python/python.exe is actually present;
    # incomplete extractions and unrelated folders are ignored.
    $installedWinPythons = @(
        Get-ChildItem -LiteralPath $pythonsRoot -Directory |
            ForEach-Object {
                if ($_.Name -match '^WPy64-(\d+)$' -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName "python\python.exe") -PathType Leaf)) {
                    $numericVersion = 0L
                    if ([long]::TryParse($Matches[1], [ref]$numericVersion)) {
                        [pscustomobject]@{
                            Name = $_.Name
                            NumericVersion = $numericVersion
                        }
                    }
                }
            }
    )

    if ($installedWinPythons.Count -eq 0) {
        throw "No installed WinPython matching WPy64-<numeric-version> was found in: $pythonsRoot"
    }

    $WinPythonName = ($installedWinPythons |
        Sort-Object -Property NumericVersion, Name -Descending |
        Select-Object -First 1).Name
}

$winPythonRoot = Join-Path $pythonsRoot $WinPythonName
$winPythonExecutable = Join-Path $winPythonRoot "python\python.exe"
if (-not (Test-Path -LiteralPath $winPythonExecutable -PathType Leaf)) {
    throw "WinPython executable was not found: $winPythonExecutable"
}

$venvName = "default-$WinPythonName"
$venvRoot = Join-Path $venvsRoot $venvName
$venvExecutable = Join-Path $venvRoot "Scripts\python.exe"
$venvConfiguration = Join-Path $venvRoot "pyvenv.cfg"

if (Test-Path -LiteralPath $venvRoot) {
    if (-not (Test-Path -LiteralPath $venvRoot -PathType Container)) {
        throw "The default venv path exists and is not a directory: $venvRoot"
    }
    if (-not (Test-Path -LiteralPath $venvExecutable -PathType Leaf) -or
        -not (Test-Path -LiteralPath $venvConfiguration -PathType Leaf)) {
        throw "The default venv directory already exists but is incomplete: $venvRoot"
    }

    $configurationText = Get-Content -LiteralPath $venvConfiguration -Raw
    if ($configurationText -notmatch '(?im)^include-system-site-packages\s*=\s*true\s*$') {
        throw "The existing default venv does not expose WinPython site-packages: $venvRoot"
    }

    Write-Host "[OK] Default Python venv is already available:" -ForegroundColor Green
    Write-Host "  $venvRoot"
    return
}

if (-not $PSCmdlet.ShouldProcess($venvRoot, "Create a transparent venv for $WinPythonName")) {
    return
}

& $winPythonExecutable -m venv --system-site-packages --without-pip $venvRoot
if ($LASTEXITCODE -ne 0) {
    throw "WinPython failed to create the default venv (exit code $LASTEXITCODE)."
}

if (-not (Test-Path -LiteralPath $venvExecutable -PathType Leaf) -or
    -not (Test-Path -LiteralPath $venvConfiguration -PathType Leaf)) {
    throw "The default venv was not created correctly: $venvRoot"
}

$configurationText = Get-Content -LiteralPath $venvConfiguration -Raw
if ($configurationText -notmatch '(?im)^include-system-site-packages\s*=\s*true\s*$') {
    throw "The created venv does not expose WinPython site-packages: $venvRoot"
}

Write-Host ""
Write-Host "[OK] Default Python venv created." -ForegroundColor Green
Write-Host "Venv: $venvRoot"
Write-Host "WinPython: $winPythonRoot"
Write-Host "Python: $venvExecutable"
