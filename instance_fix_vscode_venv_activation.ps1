[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-VSCodeUserRoot {
    $codePaths = @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -match '^Code($| -)' } |
            ForEach-Object { $_.Path } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    if ($codePaths.Count -eq 0) {
        throw "Start VS Code and run this command again."
    }
    if ($codePaths.Count -gt 1) {
        throw "More than one VS Code installation is running. Keep only one open."
    }

    $codeRoot = Split-Path -Parent $codePaths[0]
    $portableUserRoot = Join-Path $codeRoot "data\user-data\User"
    if (Test-Path -LiteralPath $portableUserRoot -PathType Container) {
        return $portableUserRoot
    }

    $userRoot = Join-Path $env:APPDATA "Code\User"
    if (-not (Test-Path -LiteralPath $userRoot -PathType Container)) {
        throw "VS Code User directory was not found: $userRoot"
    }
    return $userRoot
}

function Update-VSCodePythonActivationSettings {
    param([string]$SettingsPath)

    if (Test-Path -LiteralPath $SettingsPath -PathType Leaf) {
        try {
            $settings = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 |
                ConvertFrom-Json
        }
        catch {
            throw "VS Code user settings are not valid JSON: $SettingsPath"
        }
        if ($settings -isnot [PSCustomObject]) {
            throw "VS Code user settings must contain a JSON object: $SettingsPath"
        }
    }
    else {
        $settings = [PSCustomObject]@{}
    }

    foreach ($legacyName in @(
        "python.defaultInterpreterPath",
        "python.terminal.activateEnvironment"
    )) {
        $legacyProperty = $settings.PSObject.Properties[$legacyName]
        if ($legacyProperty) {
            $settings.PSObject.Properties.Remove($legacyName)
        }
    }

    $settings | Add-Member `
        -MemberType NoteProperty `
        -Name "python-envs.terminal.autoActivationType" `
        -Value "shellStartup" `
        -Force
    $settings | Add-Member `
        -MemberType NoteProperty `
        -Name "terminal.integrated.shellIntegration.enabled" `
        -Value $true `
        -Force

    $settingsRoot = Split-Path -Parent $SettingsPath
    [void](New-Item -ItemType Directory -Path $settingsRoot -Force)
    $content = ($settings | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    [IO.File]::WriteAllText(
        $SettingsPath,
        $content,
        (New-Object Text.UTF8Encoding($false))
    )
}

function Update-PowerShellPythonActivationProfile {
    param([string]$ProfilePath)

    $activationBlock = @'
#region vscode python
#version: 0.1.1
if (-not $env:VSCODE_PYTHON_AUTOACTIVATE_GUARD) {
    $env:VSCODE_PYTHON_AUTOACTIVATE_GUARD = '1'
    if (($env:TERM_PROGRAM -eq 'vscode') -and ($null -ne $env:VSCODE_PYTHON_PWSH_ACTIVATE)) {
        try {
            Invoke-Expression $env:VSCODE_PYTHON_PWSH_ACTIVATE
        } catch {
            $psVersion = $PSVersionTable.PSVersion.Major
            Write-Error "Failed to activate Python environment (PowerShell $psVersion): $_" -ErrorAction Continue
        }
    }
}
#endregion vscode python
'@

    $profileContent = if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) {
        Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8
    }
    else {
        ""
    }

    $regionPattern = '(?ms)^\s*#region vscode python\r?\n.*?^\s*#endregion vscode python\s*(?:\r?\n)?'
    if ([regex]::IsMatch($profileContent, $regionPattern)) {
        $literalReplacement = (
            $activationBlock.Trim() + [Environment]::NewLine
        ).Replace('$', '$$')
        $profileContent = [regex]::Replace(
            $profileContent,
            $regionPattern,
            $literalReplacement
        )
    }
    else {
        $prefix = if ([string]::IsNullOrWhiteSpace($profileContent)) {
            ""
        }
        else {
            $profileContent.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine
        }
        $profileContent = $prefix + $activationBlock.Trim() + [Environment]::NewLine
    }

    $profileRoot = Split-Path -Parent $ProfilePath
    [void](New-Item -ItemType Directory -Path $profileRoot -Force)
    [IO.File]::WriteAllText(
        $ProfilePath,
        $profileContent,
        (New-Object Text.UTF8Encoding($false))
    )
}

$userRoot = Resolve-VSCodeUserRoot
$settingsPath = Join-Path $userRoot "settings.json"
$profilePath = $PROFILE.CurrentUserCurrentHost

if ($PSCmdlet.ShouldProcess("CurrentUser", "Set PowerShell execution policy to RemoteSigned")) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}
if (-not $WhatIfPreference -and
    (Get-ExecutionPolicy) -notin @("RemoteSigned", "Unrestricted", "Bypass")) {
    throw "PowerShell scripts are still blocked by the effective execution policy: $(Get-ExecutionPolicy)"
}

if ($PSCmdlet.ShouldProcess($settingsPath, "Configure reliable VS Code Python environment activation")) {
    Update-VSCodePythonActivationSettings -SettingsPath $settingsPath
}
if ($PSCmdlet.ShouldProcess($profilePath, "Install the VS Code Python activation startup block")) {
    Update-PowerShellPythonActivationProfile -ProfilePath $profilePath
}

Write-Host ""
Write-Host "[OK] VS Code Python venv activation is configured." -ForegroundColor Green
Write-Host "Settings: $settingsPath"
Write-Host "Profile:  $profilePath"
Write-Host "Policy:   $(Get-ExecutionPolicy -Scope CurrentUser) (CurrentUser)"
Write-Host "Close all integrated terminals and run 'Developer: Reload Window' in VS Code."
