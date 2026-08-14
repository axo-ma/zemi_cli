[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArguments,

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Write-ColoredCommand {
    param(
        [string]$Prefix,
        [string]$Highlight,
        [string]$Suffix,
        [string]$Description
    )

    Write-Host "- $Prefix" -NoNewline
    if ($Highlight) {
        Write-Host $Highlight -ForegroundColor Yellow -NoNewline
    }
    if ($Suffix) {
        Write-Host $Suffix -ForegroundColor Cyan
    }
    else {
        Write-Host ""
    }
    Write-Host "  - $Description" -ForegroundColor DarkGray
}

$commandTokens = @($Command) + @($CommandArguments)
$commandTokenCount = if ($Command -eq "debug") { 3 } else { 2 }
$commandPath = @($commandTokens | Select-Object -First $commandTokenCount) -join " "
$scriptArguments = @($commandTokens | Select-Object -Skip $commandTokenCount)
if ($WhatIf) {
    $scriptArguments += "-WhatIf"
}

switch ($commandPath.Trim()) {
    "hello" {
        Write-Host "Hello from ZEMI!" -ForegroundColor Green
        return
    }
    { $_ -in @("help", "-h", "--help") } {
        Write-Host ""
        Write-ColoredCommand `
            -Prefix "zemi hello" `
            -Description "Test that the ZEMI CLI is available."
        Write-ColoredCommand `
            -Prefix "zemi help" `
            -Description "Show the available ZEMI commands."
        Write-Host ""
        Write-ColoredCommand `
            -Prefix "zemi instance create" `
            -Description "Create a new experimental ZEMI Instance."
        Write-ColoredCommand `
            -Prefix "zemi instance " `
            -Highlight "deploy-winpython" `
            -Description "Download, verify, and extract WinPython into the current Instance."
        Write-ColoredCommand `
            -Prefix "zemi instance setup" `
            -Suffix "-vscode-workspace" `
            -Description "Create the default Python venv and configure the Instance workspace."
        Write-ColoredCommand `
            -Prefix "zemi instance fix-vscode-" `
            -Highlight "venv-activation" `
            -Description "Fix reliable Python venv activation in new VS Code terminals."
        Write-Host ""
        Write-ColoredCommand `
            -Prefix "zemi component create" `
            -Description "Create a component from the template and add it to the Instance workspace."
        Write-Host ""
        Write-ColoredCommand `
            -Prefix "zemi vscode " `
            -Highlight "install-cli" `
            -Description "Add the ZEMI CLI to the VS Code integrated terminal PATH."
        Write-ColoredCommand `
            -Prefix "zemi vscode " `
            -Highlight "reset-python-settings" `
            -Description "Reset Python and Jupyter settings for the active VS Code installation."
        Write-Host ""
        Write-Host "DEBUG COMMANDS" -ForegroundColor Magenta
        Write-Host "  Commands in this section are intended only for debugging." -ForegroundColor DarkYellow
        Write-Host ""
        Write-ColoredCommand `
            -Prefix "zemi debug component " `
            -Highlight "set-default-" `
            -Suffix "python-venv" `
            -Description "Configure the current project using a relative default venv path."
        Write-ColoredCommand `
            -Prefix "zemi debug component " `
            -Highlight "set-default-" `
            -Suffix "python-venv2" `
            -Description "Configure the current project using an absolute default venv path."
        Write-Host ""
        return
    }
    "vscode install-cli" { $scriptName = "vscode_install_cli.ps1" }
    "component create" { $scriptName = "component_create.ps1" }
    "debug component set-default-python-venv" {
        $scriptName = "debug_component_set_default_python_venv.ps1"
    }
    "debug component set-default-python-venv2" {
        $scriptName = "debug_component_set_default_python_venv.ps1"
        $scriptArguments += "-AbsolutePath"
    }
    "instance create" { $scriptName = "instance_create.ps1" }
    "instance deploy-winpython" { $scriptName = "instance_deploy_winpython.ps1" }
    "instance fix-vscode-venv-activation" { $scriptName = "instance_fix_vscode_venv_activation.ps1" }
    "instance setup-vscode-workspace" { $scriptName = "instance_setup_vscode_workspace.ps1" }
    "vscode reset-python-settings" { $scriptName = "vscode_reset_python_settings.ps1" }
    default {
        $fullCommand = (@($Command) + @($CommandArguments)) -join " "
        Write-Host "Unknown ZEMI command: $fullCommand" -ForegroundColor Red
        Write-Host "Run 'zemi help' to see available commands."
        exit 1
    }
}

$scriptPath = Join-Path $PSScriptRoot $scriptName
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @scriptArguments
exit $LASTEXITCODE
