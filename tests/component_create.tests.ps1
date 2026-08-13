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
    $commandScriptContent = Get-Content -LiteralPath $commandScript -Raw -Encoding UTF8
    if ($commandScriptContent -match 'defaultInterpreterPath|Find-LatestDefaultPythonVenv|\.vscode') {
        throw "Component creation still contains Python environment or VS Code settings logic."
    }

    $workspaceDefinition = $syntaxTree.Find(
        { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Add-ComponentToVSCodeWorkspace" },
        $true
    )
    Invoke-Expression $workspaceDefinition.Extent.Text
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

    & $commandScript -InstancePath $testRoot -ComponentName "new-component" -NoRepository -Yes -WhatIf
    if (Test-Path -LiteralPath (Join-Path $testRoot "new-component")) {
        throw "WhatIf unexpectedly created the component."
    }

    Write-Host "[OK] component create tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
