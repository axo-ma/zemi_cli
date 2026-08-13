$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "debug_component_set_default_python_venv.ps1"
$instanceRoot = Split-Path -Parent $cliRoot
$temporaryRoot = Join-Path $instanceRoot "_tmp"

if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
}

$testRoot = Join-Path $temporaryRoot ("zemi-cli-component-default-venv-" + [guid]::NewGuid().ToString("N"))
$originalLocation = (Get-Location).ProviderPath

try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    [void](New-Item -ItemType File -Path (Join-Path $testRoot ".zemiinst_exp"))
    $componentRoot = Join-Path $testRoot "component"
    $nestedRoot = Join-Path $componentRoot "nested"
    [void](New-Item -ItemType Directory -Path $nestedRoot -Force)
    [void](New-Item -ItemType File -Path (Join-Path $componentRoot ".zemicomp"))

    foreach ($version in @("312101", "313100")) {
        $venvRoot = Join-Path $testRoot "_venvs\default-WPy64-$version"
        [void](New-Item -ItemType Directory -Path (Join-Path $venvRoot "Scripts") -Force)
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "Scripts\python.exe"))
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "pyvenv.cfg"))
    }

    $vscodeRoot = Join-Path $componentRoot ".vscode"
    [void](New-Item -ItemType Directory -Path $vscodeRoot)
    Set-Content -LiteralPath (Join-Path $vscodeRoot "settings.json") `
        -Encoding UTF8 `
        -Value '{"editor.formatOnSave":true}'

    Set-Location -LiteralPath $nestedRoot
    & $commandScript

    $settings = Get-Content -LiteralPath (Join-Path $vscodeRoot "settings.json") -Raw |
        ConvertFrom-Json
    $expectedPython = '${workspaceFolder}/../_venvs/default-WPy64-313100/Scripts/python.exe'
    if ($settings.'python.defaultInterpreterPath' -cne $expectedPython) {
        throw "The newest default Python venv was not assigned to the component."
    }
    if ($settings.'editor.formatOnSave' -ne $true) {
        throw "An existing VS Code setting was not preserved."
    }

    $workRoot = Join-Path $testRoot "workspace-root"
    $workRootNested = Join-Path $workRoot "nested"
    [void](New-Item -ItemType Directory -Path $workRootNested -Force)
    [void](New-Item -ItemType File -Path (Join-Path $workRoot ".zemiworkroot"))

    Set-Location -LiteralPath $workRootNested
    & $commandScript

    $workRootSettingsPath = Join-Path $workRoot ".vscode\settings.json"
    if (-not (Test-Path -LiteralPath $workRootSettingsPath -PathType Leaf)) {
        throw "VS Code settings were not created for a .zemiworkroot project."
    }
    $workRootSettings = Get-Content -LiteralPath $workRootSettingsPath -Raw | ConvertFrom-Json
    if ($workRootSettings.'python.defaultInterpreterPath' -cne $expectedPython) {
        throw "The default Python venv was not assigned to the .zemiworkroot project."
    }

    & $commandScript -AbsolutePath
    $absoluteSettings = Get-Content -LiteralPath $workRootSettingsPath -Raw | ConvertFrom-Json
    $expectedAbsolutePython = [IO.Path]::GetFullPath(
        (Join-Path $testRoot "_venvs\default-WPy64-313100\Scripts\python.exe")
    )
    if ($absoluteSettings.'python.defaultInterpreterPath' -cne $expectedAbsolutePython) {
        throw "The absolute-path debug mode did not write the absolute Python path."
    }

    Write-Host "[OK] debug component set-default-python-venv tests passed." -ForegroundColor Green
}
finally {
    Set-Location -LiteralPath $originalLocation
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
