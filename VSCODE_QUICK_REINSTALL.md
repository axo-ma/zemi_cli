# Quick VS Code Reinstallation for ZEMI

These instructions apply to Windows 10/11. You do not need to remove project
directories, Git repositories, WinPython, or ZEMI virtual environments.

## 1. Complete removal

Disable Settings Sync if it is enabled, close every VS Code window, open a
separate PowerShell window, and run:

```powershell
Set-Location "C:\Users\Axoman\Documents\ZEMI\zemi_cli"
.\vscode_clean_uninstall.ps1 -WhatIf
.\vscode_clean_uninstall.ps1
```

Review the targets with `-WhatIf` first. For the actual removal, enter
`DELETE`. The script does not request any other confirmation.

Restart Windows after the command finishes.

## 2. Obtain the official installer

The preferred option is to download the **User Installer x64, Stable** from the
official page:

<https://code.visualstudio.com/Download>

Direct official link to the current User Installer x64:

<https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user>

The script verifies the installer's Microsoft digital signature before running
it.

Manual download is optional. Without `-InstallerPath`, the script uses
`winget` and the `Microsoft.VisualStudioCode` package.

## 3. Quick installation

After restarting Windows, open PowerShell and navigate to `zemi_cli`:

```powershell
Set-Location "C:\Users\Axoman\Documents\ZEMI\zemi_cli"
```

If you downloaded the installer manually:

```powershell
.\vscode_quick_install.ps1 -InstallerPath "$env:USERPROFILE\Downloads\VSCodeUserSetup-x64.exe"
```

Replace the file name with the actual downloaded installer name.

If you did not download the installer:

```powershell
.\vscode_quick_install.ps1
```

The script installs VS Code Stable and these extensions:

- Microsoft Python (`ms-python.python`);
- Pylance (`ms-python.vscode-pylance`);
- Python Debugger (`ms-python.debugpy`);
- Python Environments (`ms-python.vscode-python-envs`);
- Jupyter (`ms-toolsai.jupyter`).

The script does not start or configure VS Code, modify the user
`settings.json`, add ZEMI CLI to the terminal `PATH`, or install the local
ZEMI Python Environment extension.

## 4. Verification

Start VS Code manually, then:

1. Do not enable Settings Sync until the clean test is complete.
2. Check the installed Marketplace extensions in the Extensions panel.
3. Perform the remaining ZEMI installation and verification separately.
