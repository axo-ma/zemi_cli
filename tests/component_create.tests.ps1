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

    $missingVenvFailed = $false
    try {
        & $commandScript -InstancePath $testRoot -ComponentName "missing-env" -NoRepository -Yes -WhatIf
    }
    catch {
        $missingVenvFailed = $_.Exception.Message -match 'zemi instance set-default-python-venv' -and
            $_.Exception.Message -match 'component was not created'
    }
    if (-not $missingVenvFailed) {
        throw "Component creation did not reject an Instance without a default venv."
    }
    if (Test-Path -LiteralPath (Join-Path $testRoot "missing-env")) {
        throw "Component creation modified the target when the default venv was missing."
    }

    foreach ($version in @("312101", "313100")) {
        $venvRoot = Join-Path $testRoot "_venvs\default-WPy64-$version"
        [void](New-Item -ItemType Directory -Path (Join-Path $venvRoot "Scripts") -Force)
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "Scripts\python.exe"))
        [void](New-Item -ItemType File -Path (Join-Path $venvRoot "pyvenv.cfg"))
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
    $finderDefinition = $syntaxTree.Find(
        { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Find-LatestDefaultPythonVenv" },
        $true
    )
    Invoke-Expression $finderDefinition.Extent.Text
    $selectedVenv = Find-LatestDefaultPythonVenv -InstanceRoot $testRoot
    if ($selectedVenv.Name -ne "default-WPy64-313100") {
        throw "Component creation did not select the default venv for the newest WinPython."
    }

    $pathDefinition = $syntaxTree.Find(
        { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Get-VSCodeDefaultInterpreterPath" },
        $true
    )
    Invoke-Expression $pathDefinition.Extent.Text
    $interpreterPath = Get-VSCodeDefaultInterpreterPath `
        -ProjectRoot (Join-Path $testRoot "latest-env") `
        -PythonPath $selectedVenv.PythonPath
    $expectedInterpreterPath = '${workspaceFolder}/../_venvs/default-WPy64-313100/Scripts/python.exe'
    if ($interpreterPath -cne $expectedInterpreterPath) {
        throw "Unexpected VS Code interpreter path: $interpreterPath"
    }

    & $commandScript -InstancePath $testRoot -ComponentName "latest-env" -NoRepository -Yes -WhatIf
    if (Test-Path -LiteralPath (Join-Path $testRoot "latest-env")) {
        throw "WhatIf unexpectedly created the component."
    }

    Write-Host "[OK] component create tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
