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
        -Value "include-system-site-packages = true`nprompt = default-WinPy"
    $projectSettings = [ordered]@{
        component_custom = '{"editor.formatOnSave":true,"python.defaultInterpreterPath":"C:/custom/python.exe","python-envs.pythonProjects":[{"path":"."}],"python-envs.workspaceSearchPaths":["old"]}'
        component_empty = '{"python.defaultInterpreterPath":""}'
        component_null = '{"python.defaultInterpreterPath":null}'
        component_whitespace = '{"python.defaultInterpreterPath":"   "}'
    }
    foreach ($projectName in $projectSettings.Keys) {
        [void](New-Item -ItemType Directory -Path (Join-Path $testRoot $projectName))
        [void](New-Item -ItemType File -Path (Join-Path $testRoot "$projectName\.zemicomp"))
        [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "$projectName\.vscode"))
        [IO.File]::WriteAllText(
            (Join-Path $testRoot "$projectName\.vscode\settings.json"),
            $projectSettings[$projectName],
            (New-Object Text.UTF8Encoding($false))
        )
    }
    [void](New-Item -ItemType Directory -Path (Join-Path $testRoot "project_missing"))
    [void](New-Item -ItemType File -Path (Join-Path $testRoot "project_missing\.zemiworkroot"))
    & $commandScript -InstancePath $testRoot

    $workspacePath = Join-Path $testRoot ((Split-Path -Leaf $testRoot) + ".code-workspace")
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Leaf)) {
        throw "The instance-named VS Code workspace was not created."
    }
    $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $expectedFolders = 'component_custom,component_empty,component_null,component_whitespace,project_missing'
    if (@($workspace.folders.path) -join ',' -cne $expectedFolders) {
        throw "The workspace does not contain all marked roots."
    }
    if ($workspace.settings.PSObject.Properties["python.defaultInterpreterPath"] -or
        $workspace.settings.PSObject.Properties["python.terminal.activateEnvironment"]) {
        throw "The workspace still contains legacy Python settings."
    }
    if ($workspace.settings.PSObject.Properties["terminal.integrated.cwd"]) {
        throw "The workspace unexpectedly configures the terminal directory."
    }

    $expectedPython = '${workspaceFolder}/../_venvs/default-WPy64-313100/Scripts/python.exe'
    foreach ($projectName in @("component_empty", "component_null", "component_whitespace", "project_missing")) {
        $settingsPath = Join-Path $testRoot "$projectName\.vscode\settings.json"
        $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($settings.'python.defaultInterpreterPath' -cne $expectedPython) {
            throw "The project default Python interpreter is incorrect: $projectName"
        }
        if ($settings.'python.terminal.activateEnvironment' -cne $true) {
            throw "The project does not enable Python environment activation: $projectName"
        }
        if ($settings.PSObject.Properties["python-envs.pythonProjects"] -or
            $settings.PSObject.Properties["python-envs.workspaceSearchPaths"]) {
            throw "The project still contains Python Environments project settings: $projectName"
        }
    }
    $componentSettings = Get-Content `
        -LiteralPath (Join-Path $testRoot "component_custom\.vscode\settings.json") `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    if ($componentSettings.'python.defaultInterpreterPath' -cne "C:/custom/python.exe") {
        throw "Project setup replaced a configured custom Python interpreter."
    }
    if ($componentSettings.'python.terminal.activateEnvironment' -cne $true) {
        throw "Project setup did not enable Python environment activation."
    }
    if ($componentSettings.'editor.formatOnSave' -ne $true) {
        throw "Project setup did not preserve unrelated VS Code settings."
    }
    if ($componentSettings.PSObject.Properties["python-envs.pythonProjects"] -or
        $componentSettings.PSObject.Properties["python-envs.workspaceSearchPaths"]) {
        throw "Project setup did not remove legacy Python Environments settings."
    }

    & $commandScript -InstancePath $testRoot
    $componentSettings = Get-Content `
        -LiteralPath (Join-Path $testRoot "component_custom\.vscode\settings.json") `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    if ($componentSettings.'python.defaultInterpreterPath' -cne "C:/custom/python.exe") {
        throw "A repeated setup replaced a configured custom Python interpreter."
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
