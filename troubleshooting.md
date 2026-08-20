# Troubleshooting ZEMI

Local ZEMI environments are designed for experimentation. Most files and
directories created automatically inside a ZEMI Instance can be recreated by
running the corresponding ZEMI command again. ZEMI-generated settings, virtual
environments, and other local artifacts should not be committed to Git.

This does not mean that every file inside an Instance is disposable. Do not
delete your source code, data, secrets, Git repositories, or any other file
that cannot be recreated. Before removing anything, confirm that a documented
ZEMI command creates it and that you understand how to restore it.

For the complete installation and setup workflow, see
[Developer Path: Getting Started with ZEMI](getting_started.md).

## Resetting a Component's Python settings

Normally, `zemi instance setup-vscode-workspace` and `00_init.py` configure the
Python environments for ZEMI Components automatically. To reset a Component's
VS Code settings completely:

1. Close all terminals and notebooks that use the Component.
2. Delete `<component>/.vscode`.
3. From the ZEMI Instance root, run:

   ```powershell
   zemi instance setup-vscode-workspace
   ```

4. The command recreates `.vscode/settings.json` with the Instance's default
   environment.
5. From the Component root, run:

   ```powershell
   python 00_init.py
   ```

6. The script creates or updates the Component `.venv` and writes it to
   `python.defaultInterpreterPath`.
7. Open a new terminal or run **Developer: Reload Window** in VS Code.

During normal operation, `zemi instance setup-vscode-workspace` preserves
unrelated properties in an existing `settings.json` and preserves an existing
non-empty `python.defaultInterpreterPath`. Deleting the entire `.vscode`
directory is a full reset and also removes any Component-specific VS Code
settings that you added yourself.

## Selecting the Python interpreter manually

The ZEMI Python Environment extension automatically selects the interpreter
configured in `.vscode/settings.json`. While ZEMI is changing that setting, VS
Code may display a notification or a **Select Python Interpreter** dialog.
Close it with the **X** button and wait for the ZEMI command to finish.

If automatic selection does not complete, select the interpreter manually.
Use the exact path stored in:

```text
<component>/.vscode/settings.json
→ python.defaultInterpreterPath
```

Selecting that interpreter manually does not interfere with ZEMI.

## Selecting a Jupyter kernel

The ZEMI extension does not currently select kernels for `.ipynb` files
automatically. For each notebook, select the kernel whose interpreter matches:

```text
<component>/.vscode/settings.json
→ python.defaultInterpreterPath
```

Do not select the system Python or the base WinPython in place of the
Component's `.venv`.

## Copying or moving a ZEMI Instance

A ZEMI Instance directory can be copied or moved. After relocating it:

1. Open `<instance-name>.code-workspace` from the new location.
2. If necessary, run this command from the Instance root:

   ```powershell
   zemi instance setup-vscode-workspace
   ```

3. For each affected Component, run this command again if necessary:

   ```powershell
   python 00_init.py
   ```

User-defined configuration is not guaranteed to be portable if it contains
absolute paths to the old location.

## Recovering a ZEMI Instance

Use the command that owns an automatically generated element:

| Damaged or missing element | Recovery action |
| --- | --- |
| Instance workspace file | Repeat the applicable Instance creation or workspace setup step from `getting_started.md`. |
| WinPython under `@inst/_pythons` | Run `zemi instance deploy-winpython`. |
| Default environments or Component defaults | Run `zemi instance setup-vscode-workspace`. |
| Component `.venv` | Run `python 00_init.py` from the Component root. |
| Component `.vscode/settings.json` | Run `zemi instance setup-vscode-workspace` from the Instance root, then `python 00_init.py` from the Component root. |

For broader recovery, repeat the applicable steps in
[getting_started.md](getting_started.md) for the existing Instance.

Do not remove these items unless you have a deliberate, verified recovery plan:

- source code and user data;
- `.git` directories or other Git repository contents;
- `.zemiinst_*`, `.zemicomp`, and `.zemiworkroot` marker files;
- secrets, configuration, and resources that are not created by ZEMI commands.

## Reinstalling or cleaning VS Code

VS Code itself can be uninstalled and installed again. The ZEMI Instance,
Components, and their Python environments do not depend on the VS Code
installation remaining intact.

After reinstalling VS Code, repeat the ZEMI integration step. From the cloned
`zemi_cli` repository, run:

```powershell
.\zemi.cmd vscode install-zemi
```

This command:

- adds the `zemi_cli` directory to `terminal.integrated.env.windows.PATH`;
- makes `zemi` available in new VS Code integrated terminals;
- installs the ZEMI Python Environment extension;
- restores automatic Python interpreter selection for ZEMI Components.

After the command finishes:

1. Run **Developer: Reload Window**.
2. Close all previously opened integrated terminals.
3. Open a new terminal.
4. Verify the CLI:

   ```powershell
   zemi hello
   ```

If VS Code displays many obsolete or unnecessary Python environments or
kernels, run:

```powershell
zemi vscode reset-python-settings
```

This command clears Python and Jupyter settings for the active VS Code
installation and helps remove references to old environments and kernels from
the UI. It does not delete physical `.venv` directories, WinPython
installations, Components, or user code. Restart VS Code after it completes.
If necessary, restore current Component settings with:

```powershell
zemi instance setup-vscode-workspace
python 00_init.py
```

Run the first command from the Instance root and the second from each affected
Component root.

## Working with Components and libraries

The
[ZEMI Component template guide](https://github.com/axo-ma/zemi_component_template/blob/main/README.md)
is the primary guide to creating a Component, running `00_init.py`, updating
the Z-bundle and C-bundle, adding dependencies through `00_init.toml`, and
verifying the Component with `playbook.ipynb`.
