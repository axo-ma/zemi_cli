[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArguments
)

$ErrorActionPreference = "Stop"

$commandPath = (@($Command) + @($CommandArguments | Select-Object -First 1)) -join " "
$scriptArguments = @($CommandArguments | Select-Object -Skip 1)

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
  cli install - Add ZEMI CLI to VS Code
  component create - Create a ZEMI Component from the GitHub template
  component create-python-env - Create the component .venv from Instance WinPython
  instance create - Create a ZEMI Instance
  winpython download - Download WinPython
  vscode enable-multi-root - Create or update the ZEMI multi-root workspace
  vscode reset-python-settings - Reset Python and Jupyter in VS Code
"@
        return
    }
    "cli install" { $scriptName = "cli_install.ps1" }
    "component create" { $scriptName = "component_create.ps1" }
    "component create-python-env" { $scriptName = "component_create_python_env.ps1" }
    "instance create" { $scriptName = "instance_create.ps1" }
    "winpython download" { $scriptName = "winpython_download.ps1" }
    "vscode enable-multi-root" { $scriptName = "vscode_enable_multi_root.ps1" }
    "vscode reset-python-settings" { $scriptName = "vscode_reset_python_settings.ps1" }
    default {
        $fullCommand = (@($Command) + @($CommandArguments)) -join " "
        Write-Host "Unknown ZEMI command: $fullCommand" -ForegroundColor Red
        Write-Host "Run 'zemi help' to see available commands."
        exit 1
    }
}

& (Join-Path $PSScriptRoot $scriptName) @scriptArguments
