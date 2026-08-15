$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$cliRoot = Split-Path -Parent $PSScriptRoot
$commandScript = Join-Path $cliRoot "vscode_fix_venv_activation.ps1"
$instanceRoot = Split-Path -Parent $cliRoot
$temporaryRoot = Join-Path $instanceRoot "_tmp"

if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
}

$testRoot = Join-Path $temporaryRoot ("zemi-cli-fix-vscode-activation-" + [guid]::NewGuid().ToString("N"))

try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    $tokens = $null
    $parseErrors = $null
    $syntaxTree = [Management.Automation.Language.Parser]::ParseFile(
        $commandScript,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "vscode_fix_venv_activation.ps1 contains PowerShell syntax errors."
    }

    foreach ($functionName in @(
        "Set-ZemiPowerShellExecutionPolicy",
        "Update-VSCodePythonActivationSettings",
        "Update-PowerShellPythonActivationProfile"
    )) {
        $definition = $syntaxTree.Find(
            { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName },
            $true
        )
        Invoke-Expression $definition.Extent.Text
    }

    $policyFunction = $syntaxTree.Find(
        { param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Set-ZemiPowerShellExecutionPolicy" },
        $true
    ).Extent.Text
    if ($policyFunction -notmatch 'Get-ExecutionPolicy\s+-Scope\s+CurrentUser' -or
        $policyFunction -notmatch '"RemoteSigned",\s*"Unrestricted",\s*"Bypass"') {
        throw "The execution-policy helper does not handle an overriding allowed policy."
    }

    $settingsPath = Join-Path $testRoot "User\settings.json"
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $settingsPath))
    [IO.File]::WriteAllText(
        $settingsPath,
        '{"editor.formatOnSave":true,"python.defaultInterpreterPath":"old","python.terminal.activateEnvironment":true}',
        (New-Object Text.UTF8Encoding($false))
    )
    Update-VSCodePythonActivationSettings -SettingsPath $settingsPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.'editor.formatOnSave' -ne $true) {
        throw "The activation fix did not preserve unrelated VS Code settings."
    }
    if ($settings.'python-envs.terminal.autoActivationType' -cne "shellStartup") {
        throw "The activation fix did not enable shellStartup."
    }
    if ($settings.'terminal.integrated.shellIntegration.enabled' -ne $true) {
        throw "The activation fix did not enable terminal shell integration."
    }
    if ($settings.PSObject.Properties["python.defaultInterpreterPath"] -or
        $settings.PSObject.Properties["python.terminal.activateEnvironment"]) {
        throw "The activation fix did not remove legacy user settings."
    }

    $profilePath = Join-Path $testRoot "Microsoft.PowerShell_profile.ps1"
    [IO.File]::WriteAllText(
        $profilePath,
        "before`n#region vscode python`nold block`n#endregion vscode python`nafter`n",
        (New-Object Text.UTF8Encoding($false))
    )
    Update-PowerShellPythonActivationProfile -ProfilePath $profilePath
    Update-PowerShellPythonActivationProfile -ProfilePath $profilePath
    $profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    if ($profile -notmatch 'VSCODE_PYTHON_PWSH_ACTIVATE' -or
        $profile -notmatch 'VSCODE_PYTHON_AUTOACTIVATE_GUARD' -or
        $profile -notmatch '#version: 0\.1\.1') {
        throw "The current Python Environments startup block was not written."
    }
    if ($profile -match 'VSCODE_PWSH_ACTIVATE' -or
        $profile -notmatch 'before' -or
        $profile -notmatch 'after') {
        throw "The profile update did not replace only the legacy activation block."
    }
    if ([regex]::Matches($profile, '#region vscode python').Count -ne 1) {
        throw "The profile update is not idempotent:`n$profile"
    }

    Write-Host "[OK] vscode fix-venv-activation tests passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
