$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "instance_set_default_python_venv.ps1"
$instanceRoot = Split-Path -Parent $cliRoot
$temporaryRoot = Join-Path $instanceRoot "_tmp"

if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
}

$testRoot = Join-Path $temporaryRoot ("zemi-cli-set-default-venv-" + [guid]::NewGuid().ToString("N"))

try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    [void](New-Item -ItemType File -Path (Join-Path $testRoot ".zemiinst_exp"))
    [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "_pythons\WPy64-312101\python"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "_pythons\WPy64-312101\python\python.exe"))
    [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "_pythons\WPy64-313100\python"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "_pythons\WPy64-313100\python\python.exe"))

    & $commandScript -InstancePath $testRoot -WhatIf
    if (Test-Path -LiteralPath (Join-Path $testRoot "_venvs\default-WPy64-313100")) {
        throw "WhatIf unexpectedly created the venv."
    }

    $latestVenvRoot = Join-Path $testRoot "_venvs\default-WPy64-313100"
    [void](New-Item -ItemType Directory -Path (Join-Path $latestVenvRoot "Scripts"))
    [void](New-Item -ItemType File -Path (Join-Path $latestVenvRoot "Scripts\python.exe"))
    Set-Content -LiteralPath (Join-Path $latestVenvRoot "pyvenv.cfg") `
        -Value "include-system-site-packages = true"
    & $commandScript -InstancePath $testRoot

    $invalidNameFailed = $false
    try {
        & $commandScript -InstancePath $testRoot -WinPythonName ".." -WhatIf
    }
    catch {
        $invalidNameFailed = $_.Exception.Message -match 'single valid folder name'
    }
    if (-not $invalidNameFailed) {
        throw "An invalid WinPython folder name was not rejected."
    }

    Write-Host "[OK] instance set-default-python-venv tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
