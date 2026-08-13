$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "instance_setup_vscode_workspace.ps1"
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
    [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "component_b"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "component_b\.zemicomp"))
    [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "project_a"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "project_a\.zemiworkroot"))
    & $commandScript -InstancePath $testRoot

    $workspacePath = Join-Path $testRoot ((Split-Path -Leaf $testRoot) + ".code-workspace")
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Leaf)) {
        throw "The instance-named VS Code workspace was not created."
    }
    $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($workspace.folders.path) -join ',' -cne 'component_b,project_a') {
        throw "The workspace does not contain all marked roots."
    }
    if ($workspace.settings.'python.defaultInterpreterPath' -cne $latestVenvRoot + "\Scripts\python.exe") {
        throw "The workspace default Python path is incorrect."
    }
    if ($workspace.settings.'terminal.integrated.cwd' -cne $testRoot) {
        throw "The workspace terminal directory is not the ZEMI Instance root."
    }

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

    Write-Host "[OK] instance setup-vscode-workspace tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
