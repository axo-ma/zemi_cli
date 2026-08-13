# ZEMI CLI Development Instructions

Develop ZEMI CLI as a simple portable Windows CLI without unnecessary
abstractions. Before making changes, study the existing commands and preserve
compatibility with them.

## Public interface

- Users invoke only `zemi <command>`.
- `zemi.cmd` is a minimal launcher for PowerShell, CMD, and the VS Code terminal.
- `zemi_cli.ps1` is the command dispatcher. It parses arguments and runs the
  appropriate PowerShell script.
- Do not require users to run internal `*.ps1` files directly or inspect them
  with `Get-Command`.
- Required commands:
  - `zemi hello`;
  - `zemi help`;
  - `zemi vscode install-cli`;
  - `zemi component create`;
  - `zemi instance create`;
  - `zemi instance deploy-winpython`;
  - `zemi vscode reset-python-settings`.

## File names

- Name implementation files using the `<group>_<action>.ps1` pattern.
- Examples:
  - `instance_create.ps1`;
  - `instance_deploy_winpython.ps1`;
  - `vscode_reset_python_settings.ps1`;
  - `vscode_install_cli.ps1`.
- When renaming a file, update the dispatcher, documentation, and textual
  references at the same time.

## Simplicity

- Write short, straightforward code. Do not add frameworks, classes, layers,
  auto-detection systems, backups, or removal modes without an explicit request.
- Do not create parameters that can be reliably derived from the current context.
- Do not open file or directory selection dialogs.
- If a required program is not running, display a clear error in red and exit
  the command with a nonzero status.
- `zemi hello` must quickly print `Hello from ZEMI!` without changing anything.

## Portability

- ZEMI CLI can be located anywhere on disk and exists before any ZEMI Instance.
- Never tie the CLI location to a ZEMI Instance.
- Determine the CLI root through `$PSScriptRoot`.
- Do not modify the system or user Windows `PATH`, and do not write to the registry.
- `zemi vscode install-cli` configures only VS Code by adding the CLI directory
  to `terminal.integrated.env.windows.PATH` in the user `settings.json`.
- Detect a running `Code.exe`. If VS Code is not running, display a red error.
- `zemi component create` must not create or select a Python virtual environment,
  modify `.vscode/settings.json`, or set `python.defaultInterpreterPath`.
- `zemi vscode reset-python-settings` accepts no parameters and clears only the
  Python/Jupyter settings of the running VS Code instance. Do not scan a ZEMI
  Instance, modify components, or require WinPython.

## Documentation and checks

- When changing commands, update `getting_started.md` and `zemi help` together.
