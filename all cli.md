
Текущий набор

Commands:
  hello - Test the ZEMI CLI
  cli install - Add ZEMI CLI to VS Code
  component create - Create a ZEMI Component from the GitHub template
  component create-python-env - Create the component .venv from Instance WinPython
  instance create - Create a ZEMI Instance
  winpython download - Download WinPython
  vscode enable-multi-root - Create or update the ZEMI multi-root workspace
  vscode reset-python-settings - Reset Python and Jupyter in VS Code

Целевой набор

+ cli install -> zemi vscode install-cli
+ vscode reset-python-settings -> zemi vscode reset-python-settings
+ vscode enable-multi-root -> zemi vscode enable-multi-root

+ instance create -> zemi instance create
+ winpython download -> zemi instance download-winpython
- zemi instance set-default-python-venv

- zemi component create my_component
- zemi component update-zemilib
- zemi component create-playbook

- zemi full instance create
- zemi full component create
- zemi full component update-zemilib

Debugging only
+ zemi component set-default-python-venv - относительный путь на vnenv
+ zemi component set-default-python-venv2 - абсолбтный путь на venv
