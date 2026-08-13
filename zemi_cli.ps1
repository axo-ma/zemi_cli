[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArguments,

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$commandPath = (@($Command) + @($CommandArguments | Select-Object -First 1)) -join " "
$scriptArguments = @($CommandArguments | Select-Object -Skip 1)
if ($WhatIf) {
    $scriptArguments += "-WhatIf"
}

switch ($commandPath.Trim()) {
    "hello" {
        Write-Host "Hello from ZEMI!" -ForegroundColor Green
        return
    }
    { $_ -in @("help", "-h", "--help") } {
        Write-Host @"
ZEMI CLI

Usage: zemi <command> [arguments]

Commands:
  hello - Test the ZEMI CLI
  vscode install-cli - Add ZEMI CLI to VS Code
  component create - Create a ZEMI Component from the GitHub template
  component set-default-python-venv - Set the Instance default Python venv for the current project root
  component set-default-python-venv2 - Set it using an absolute path (temporary debug command)
  instance create - Create a ZEMI Instance
  instance deploy-winpython - Download and deploy WinPython
  instance setup-vscode-workspace - Create the default Python venv and configure the Instance workspace
  vscode reset-python-settings - Reset Python and Jupyter in VS Code
"@
        return
    }
    "vscode install-cli" { $scriptName = "vscode_install_cli.ps1" }
    "component create" { $scriptName = "component_create.ps1" }
    "component set-default-python-venv" { $scriptName = "component_set_default_python_venv.ps1" }
    "component set-default-python-venv2" {
        $scriptName = "component_set_default_python_venv.ps1"
        $scriptArguments += "-AbsolutePath"
    }
    "instance create" { $scriptName = "instance_create.ps1" }
    "instance deploy-winpython" { $scriptName = "instance_deploy_winpython.ps1" }
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
