$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "component_create.ps1"
$instanceRoot = Split-Path -Parent $cliRoot
$temporaryRoot = Join-Path $instanceRoot "_tmp"

if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
}

$testRoot = Join-Path $temporaryRoot ("zemi-cli-component-create-" + [guid]::NewGuid().ToString("N"))

try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    [void](New-Item -ItemType File -Path (Join-Path $testRoot ".zemiinst_exp"))
    foreach ($version in @("312101", "313100")) {
        $venvRoot = Join-Path $testRoot "_venvs\default-WPy64-$version"
        [void](New-Item -ItemType Directory -Path (Join-Path $venvRoot "Scripts"))
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "Scripts\python.exe"))
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "pyvenv.cfg"))
    }

    & $commandScript -InstancePath $testRoot -ComponentName "missing-env" -NoRepository -Yes -WhatIf
    if (Test-Path -LiteralPath (Join-Path $testRoot "missing-env")) {
        throw "WhatIf unexpectedly created the component."
    }

    $tokens = $null
    $parseErrors = $null
    $syntaxTree = [Management.Automation.Language.Parser]::ParseFile(
        $commandScript,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "component_create.ps1 contains PowerShell syntax errors."
    }
    foreach ($functionName in @(
        "Add-ComponentToVSCodeWorkspace",
        "Find-LatestDefaultPythonVenv",
        "Set-ProjectVSCodePythonEnvironment"
    )) {
        $definition = $syntaxTree.Find(
            { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName },
            $true
        )
        Invoke-Expression $definition.Extent.Text
    }
    $workspacePath = Join-Path $testRoot ((Split-Path -Leaf $testRoot) + ".code-workspace")
    [IO.File]::WriteAllText(
        $workspacePath,
        '{"folders":[],"settings":{"existing.setting":true}}',
        (New-Object Text.UTF8Encoding($false))
    )
    [void](Add-ComponentToVSCodeWorkspace -InstanceRoot $testRoot -ComponentName "new-component")
    [void](Add-ComponentToVSCodeWorkspace -InstanceRoot $testRoot -ComponentName "new-component")
    $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($workspace.folders -isnot [array]) {
        throw "The Instance workspace folders property is not a JSON array."
    }
    if (@($workspace.folders.path) -join ',' -cne 'new-component') {
        throw "Component creation did not add the project to the Instance workspace exactly once."
    }
    if ($workspace.settings.'existing.setting' -ne $true) {
        throw "Component creation did not preserve existing workspace settings."
    }

    $defaultVenv = Find-LatestDefaultPythonVenv -InstanceRoot $testRoot
    if ($defaultVenv.Name -cne "default-WPy64-313100") {
        throw "Component creation did not select the newest default Python venv."
    }
    $projectRoot = Join-Path $testRoot "new-component"
    [void](New-Item -ItemType Directory -Path (Join-Path $projectRoot ".vscode"))
    [IO.File]::WriteAllText(
        (Join-Path $projectRoot ".vscode\settings.json"),
        '{"editor.formatOnSave":true,"python-envs.pythonProjects":[{"path":"."}],"python-envs.workspaceSearchPaths":["old"]}',
        (New-Object Text.UTF8Encoding($false))
    )
    $settingsPath = Set-ProjectVSCodePythonEnvironment `
        -ProjectRoot $projectRoot `
        -VenvRoot $defaultVenv.Root
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.'editor.formatOnSave' -ne $true) {
        throw "Component creation did not preserve unrelated project settings."
    }
    $expectedPython = '${workspaceFolder}/../_venvs/default-WPy64-313100/Scripts/python.exe'
    if ($settings.'python.defaultInterpreterPath' -cne $expectedPython) {
        throw "Component creation did not configure the exact default Python interpreter."
    }
    if ($settings.'python.terminal.activateEnvironment' -cne $true) {
        throw "Component creation did not enable Python environment activation."
    }
    if ($settings.PSObject.Properties["python-envs.pythonProjects"] -or
        $settings.PSObject.Properties["python-envs.workspaceSearchPaths"]) {
        throw "Component creation left Python Environments project settings in the project."
    }

    $existingTargetFailed = $false
    try {
        & $commandScript -InstancePath $testRoot -ComponentName "new-component" -NoRepository -Yes -WhatIf
    }
    catch {
        $existingTargetFailed = $_.Exception.Message -match 'target already exists'
    }
    if (-not $existingTargetFailed) {
        throw "Component creation did not reject an existing target."
    }

    Write-Host "[OK] component create tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
