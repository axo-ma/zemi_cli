# Developer Path: Getting Started with ZEMI

## Prerequisites

Before creating a ZEMI Instance, prepare the workstation:

1. **Git** — a standard or portable installation.
2. **Visual Studio Code** — a standard or portable installation.
3. Standard VS Code extensions:
   - Microsoft Python (`ms-python.python`);
   - Microsoft Jupyter (`ms-toolsai.jupyter`).
4. **7-Zip** — required to extract the WinPython archive.
5. Internet access — required to download WinPython and clone repositories.
6. Microsoft Office for working with Excel.

> **The `@inst` notation.** In this guide, `@inst` means the path to the root of
> a specific ZEMI Instance. It is not a literal directory name. For example, if
> the Instance is located at `D:\ZEMI\experiment-01`, then `@inst/_tmp` means
> `D:\ZEMI\experiment-01\_tmp`.

## 1. Deploying ZEMI CLI

Choose any location on disk and clone the ZEMI CLI repository:

```powershell
git clone https://github.com/axo-ma/zemi_cli.git
cd .\zemi_cli
```

Start VS Code. Only one VS Code installation should be running. Then run this
command from the ZEMI CLI directory:

```powershell
.\zemi.cmd vscode install-cli
```

The command adds the ZEMI CLI directory only to
`terminal.integrated.env.windows.PATH` in the VS Code user settings.

Close all existing integrated terminals in VS Code and open a new terminal.
Verify the global command:

```powershell
zemi hello
```

Expected output:

```text
Hello from ZEMI!
```

Run `zemi help` to see the available commands.

If VS Code previously used other Python environments or Jupyter kernels, clear
the old settings:

```powershell
zemi vscode reset-python-settings
```

Restart VS Code after the command. You can skip this step for a new installation
because the component creation command configures the interpreter automatically.

## 2. Creating a ZEMI Instance

You can create any number of independent ZEMI Instances on one machine.

To create a ZEMI Instance directory, run:

```powershell
zemi instance create
```

The command creates the selected ZEMI Instance directory and places the
`.zemiinst_exp` marker file directly in its root.

To install WinPython inside the new ZEMI Instance, navigate to its directory and
run:

```powershell
zemi instance deploy-winpython
```

The command downloads the WinPython archive to `@inst/_tmp` and offers to
extract it to `@inst/_pythons`.

To create the ZEMI Instance workspace file and configure the default Python
virtual environment, run:

```powershell
zemi instance setup-vscode-workspace
```

The command creates the default Python virtual environment in `@inst/_venvs`
and the `@inst/<instance-name>.code-workspace` file.

When it finishes, close VS Code, open `@inst/<instance-name>.code-workspace`,
and confirm trust when VS Code displays the Workspace Trust prompt.

## 3. Creating a ZEMI Component

To create a ZEMI Component from the template while inside a ZEMI Instance, run:

```powershell
zemi component create my_component
```

The command creates the component directory with a `.zemicomp` marker,
configures it to use the default Python virtual environment, and adds the
component to the current ZEMI Instance workspace.

During creation, you can specify the URL of an empty Git repository to add it as
`origin`. Leave the URL empty if you do not need a remote repository.

After creation, return to VS Code and click **Yes** if it asks whether you trust
the added component.

Review the new component, then create the first commit with VS Code or the
commands below. If `origin` is configured, push the commit to the remote
repository:

```powershell
git add -A
git commit -m "Initialize ZEMI component"
git push -u origin main
```
