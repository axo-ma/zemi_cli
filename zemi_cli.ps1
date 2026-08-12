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
  vscode install-cli - Add ZEMI CLI to VS Code
  component create - Create a ZEMI Component from the GitHub template
  instance create - Create a ZEMI Instance
  instance download-winpython - Download WinPython
  vscode enable-multi-root - Create or update the ZEMI multi-root workspace
  vscode reset-python-settings - Reset Python and Jupyter in VS Code
"@
        return
    }
    "vscode install-cli" { $scriptName = "vscode_install_cli.ps1" }
    "component create" { $scriptName = "component_create.ps1" }
    "instance create" { $scriptName = "instance_create.ps1" }
    "instance download-winpython" { $scriptName = "instance_download_winpython.ps1" }
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
